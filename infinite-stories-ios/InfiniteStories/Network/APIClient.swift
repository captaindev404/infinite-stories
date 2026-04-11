//
//  APIClient.swift
//  InfiniteStories
//
//  HTTP client for backend API with retry logic and authentication
//

import Foundation

// MARK: - API Client

@MainActor
class APIClient {
    static let shared = APIClient(
        baseURL: URL(string: AppConfiguration.backendBaseURL)!
    )

    private let baseURL: URL
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = .default
    ) {
        self.baseURL = baseURL
        self.session = session
        self.retryPolicy = retryPolicy

        // Configure JSON decoder
        self.decoder = JSONDecoder()

        // Use custom date formatter to handle fractional seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Also create an ISO8601 formatter for dates without fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        // Custom date decoding that tries both formats
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try with fractional seconds first
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 format without fractional seconds
            if let date = isoFormatter.date(from: dateString) {
                return date
            }

            // If neither works, throw an error
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date string \(dateString) does not match expected format"
            )
        }
    }

    // MARK: - Public API

    /// Make a network request with automatic retry and error handling
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - retryPolicy: Optional custom retry policy (defaults to instance policy)
    /// - Returns: Decoded response object
    /// - Throws: APIError on failure
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        // Use custom retry policy if provided, otherwise use instance default
        let policy = retryPolicy ?? self.retryPolicy

        return try await policy.execute {
            try await self.performRequest(endpoint)
        }
    }

    /// Make a network request without expecting a response body
    /// - Parameters:
    ///   - endpoint: The API endpoint to call
    ///   - retryPolicy: Optional custom retry policy
    /// - Throws: APIError on failure
    func requestVoid(
        _ endpoint: Endpoint,
        retryPolicy: RetryPolicy? = nil
    ) async throws {
        let policy = retryPolicy ?? self.retryPolicy

        try await policy.execute {
            let _: EmptyResponse = try await self.performRequest(endpoint)
        }
    }

    // MARK: - Private Implementation

    private func performRequest<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Check network availability first
        guard NetworkMonitor.shared.isConnected else {
            Logger.network.error("Request blocked: No network connection")
            throw APIError.networkUnavailable
        }

        // Build request
        var request = try buildRequest(for: endpoint)

        // Add authentication header if available
        if let token = AuthStateManager.shared.sessionToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Log request
        Logger.network.info("→ \(endpoint.method.rawValue) \(request.url?.absoluteString ?? "unknown")")

        // Perform request
        let (data, response) = try await session.data(for: request)

        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.network.error("Invalid response type")
            throw APIError.unknown(NSError(
                domain: "APIClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
            ))
        }

        // Log response
        Logger.network.info("← \(httpResponse.statusCode) \(endpoint.method.rawValue) \(request.url?.absoluteString ?? "unknown")")

        // Check HTTP status
        guard (200...299).contains(httpResponse.statusCode) else {
            let error = APIError.from(httpStatusCode: httpResponse.statusCode, data: data)
            Logger.network.error("HTTP error \(httpResponse.statusCode): \(error.localizedDescription)")

            // Handle 401 Unauthorized - flip the global session-expired flag so
            // the app root unmounts MainTabView and presents the auth screen
            // full-screen. This also wipes cookies/keychain so the next sign-in
            // starts from a clean slate (BUG-28, BUG-35).
            if case .unauthorized = error {
                await AuthStateManager.shared.handleSessionExpired()
            }

            throw error
        }

        // Decode response
        do {
            let decoded = try decoder.decode(T.self, from: data)
            Logger.network.success("✓ Successfully decoded response")
            return decoded
        } catch let decodingError as DecodingError {
            // More detailed decoding error logging
            switch decodingError {
            case .keyNotFound(let key, let context):
                Logger.network.error("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                Logger.network.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .typeMismatch(let type, let context):
                Logger.network.error("Type mismatch for \(type): \(context.debugDescription)")
                Logger.network.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .valueNotFound(let value, let context):
                Logger.network.error("Value of type \(value) not found: \(context.debugDescription)")
                Logger.network.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .dataCorrupted(let context):
                Logger.network.error("Data corrupted: \(context.debugDescription)")
                Logger.network.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            @unknown default:
                Logger.network.error("Unknown decoding error: \(decodingError.localizedDescription)")
            }

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.network.debug("Response body (first 1000 chars): \(String(responseString.prefix(1000)))")
            }

            throw APIError.decodingError(decodingError)
        } catch {
            Logger.network.error("Decoding error: \(error.localizedDescription)")

            // Log response body for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                Logger.network.debug("Response body: \(responseString)")
            }

            throw APIError.decodingError(error)
        }
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        // Build URL with path
        var urlComponents = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: true)

        // Add query items if present
        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }

        guard let url = urlComponents?.url else {
            throw APIError.unknown(NSError(
                domain: "APIClient",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL construction"]
            ))
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = 300 // 300 second timeout (5 minutes)

        // Add headers
        for (key, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body if present
        if let body = endpoint.body {
            request.httpBody = body
        }

        return request
    }
}

