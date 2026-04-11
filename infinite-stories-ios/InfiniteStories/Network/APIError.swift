//
//  APIError.swift
//  InfiniteStories
//
//  API error types with localized descriptions
//

import Foundation

enum APIError: Error {
    case networkUnavailable    // No internet connection
    case unauthorized           // 401 - Token expired/invalid
    case forbidden             // 403 - No access to resource
    case notFound              // 404 - Resource doesn't exist
    case rateLimitExceeded(resetAt: Date) // 429 - Too many requests
    case validationError(fields: [String: String]) // 400 - Invalid input
    case serverError           // 500 - Backend error
    case networkError(Error)   // Network connectivity issues
    case decodingError(Error)  // JSON parsing failed
    case unknown(Error)        // Unexpected error
}

extension APIError: LocalizedError {
    // BUG-13: All error bodies + recovery suggestions now come from
    // Localizable.xcstrings so FR users stop seeing English copy inside
    // the otherwise-FR ErrorView (e.g. session-expired card).
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "error.body.noInternet")

        case .unauthorized:
            return String(localized: "error.body.sessionExpired")

        case .forbidden:
            return String(localized: "error.body.forbidden")

        case .notFound:
            return String(localized: "error.body.notFound")

        case .rateLimitExceeded(let resetAt):
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            formatter.locale = .current
            let time = formatter.string(from: resetAt)
            return String(format: String(localized: "error.body.rateLimit %@"), time)

        case .validationError(let fields):
            let messages = fields.values.joined(separator: ", ")
            return String(format: String(localized: "error.body.validation %@"), messages)

        case .serverError:
            return String(localized: "error.body.server")

        case .networkError(let error):
            return String(format: String(localized: "error.body.network %@"), error.localizedDescription)

        case .decodingError(let error):
            return String(format: String(localized: "error.body.decoding %@"), error.localizedDescription)

        case .unknown(let error):
            return String(format: String(localized: "error.body.unknown %@"), error.localizedDescription)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "error.recovery.noInternet")

        case .unauthorized:
            return String(localized: "error.recovery.sessionExpired")

        case .forbidden:
            return String(localized: "error.recovery.forbidden")

        case .notFound:
            return String(localized: "error.recovery.notFound")

        case .rateLimitExceeded:
            return String(localized: "error.recovery.rateLimit")

        case .validationError:
            return String(localized: "error.recovery.validation")

        case .serverError:
            return String(localized: "error.recovery.server")

        case .networkError:
            return String(localized: "error.recovery.noInternet")

        case .decodingError:
            return String(localized: "error.recovery.decoding")

        case .unknown:
            return String(localized: "error.recovery.unknown")
        }
    }

    var failureReason: String? {
        switch self {
        case .networkUnavailable:
            return "Device is not connected to the internet."

        case .unauthorized:
            return "Your authentication token is invalid or expired."

        case .forbidden:
            return "You don't have the required permissions."

        case .notFound:
            return "The server couldn't find the requested resource."

        case .rateLimitExceeded(let resetAt):
            return "You've made too many requests. Limit resets at \(resetAt)."

        case .validationError(let fields):
            return "Invalid data: \(fields.keys.joined(separator: ", "))"

        case .serverError:
            return "The server encountered an internal error."

        case .networkError:
            return "Unable to connect to the server."

        case .decodingError:
            return "The server response was malformed."

        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

// MARK: - Helper for HTTP Response Mapping

extension APIError {
    static func from(httpStatusCode: Int, data: Data? = nil) -> APIError {
        switch httpStatusCode {
        case 401:
            return .unauthorized

        case 403:
            return .forbidden

        case 404:
            return .notFound

        case 429:
            // Try to parse rate limit reset time from response
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resetAtString = json["resetAt"] as? String,
               let resetAt = ISO8601DateFormatter().date(from: resetAtString) {
                return .rateLimitExceeded(resetAt: resetAt)
            }
            return .rateLimitExceeded(resetAt: Date().addingTimeInterval(3600)) // Default: 1 hour

        case 400:
            // Try to parse validation errors
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorData = json["error"] as? [String: Any],
               let details = errorData["details"] as? [String: String] {
                return .validationError(fields: details)
            }
            return .validationError(fields: ["general": "Invalid request"])

        case 500...599:
            return .serverError

        default:
            return .unknown(NSError(domain: "HTTP", code: httpStatusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP error \(httpStatusCode)"
            ]))
        }
    }
}
