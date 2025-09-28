//
//  SupabaseHelpers.swift
//  InfiniteStories
//
//  Helper types and extensions for Supabase integration
//

import Foundation

// MARK: - Helper for type-erasing Encodable values
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - AnyJSON Type for Supabase

/// A type-erased JSON value for working with Supabase
public enum AnyJSON: Codable, Equatable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([AnyJSON])
    case object([String: AnyJSON])

    // MARK: - Initialization

    public init(_ value: Bool) {
        self = .bool(value)
    }

    public init(_ value: Int) {
        self = .number(Double(value))
    }

    public init(_ value: Double) {
        self = .number(value)
    }

    public init(_ value: String) {
        self = .string(value)
    }

    public init(_ value: Any?) {
        if let value = value {
            if let bool = value as? Bool {
                self = .bool(bool)
            } else if let int = value as? Int {
                self = .number(Double(int))
            } else if let double = value as? Double {
                self = .number(double)
            } else if let string = value as? String {
                self = .string(string)
            } else if let array = value as? [Any] {
                self = .array(array.map { AnyJSON($0) })
            } else if let dict = value as? [String: Any] {
                var object: [String: AnyJSON] = [:]
                for (key, val) in dict {
                    object[key] = AnyJSON(val)
                }
                self = .object(object)
            } else if let encodable = value as? Encodable {
                // Try to encode the value to JSON and then decode it as AnyJSON
                do {
                    let data = try JSONEncoder().encode(AnyEncodable(encodable))
                    let decoded = try JSONDecoder().decode(AnyJSON.self, from: data)
                    self = decoded
                } catch {
                    self = .null
                }
            } else {
                self = .null
            }
        } else {
            self = .null
        }
    }

    // MARK: - Value Extraction

    public var value: Any? {
        switch self {
        case .null:
            return nil
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let value):
            return value.map { $0.value }
        case .object(let value):
            return value.mapValues { $0.value }
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyJSON].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyJSON].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyJSON"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Date Formatting Extensions

extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter
    }()
}

extension DateFormatter {
    static let supabase: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Supabase Response Helpers

struct SupabaseResponse<T: Decodable>: Decodable {
    let data: T?
    let error: SupabaseResponseError?
}

struct SupabaseResponseError: Decodable, Error {
    let message: String
    let details: String?
    let hint: String?
    let code: String?

    var localizedDescription: String {
        return message
    }
}

// MARK: - Database Query Helpers

extension Dictionary where Key == String, Value == Any {
    /// Convert dictionary to AnyJSON format for Supabase
    func toAnyJSON() -> [String: AnyJSON] {
        var result: [String: AnyJSON] = [:]
        for (key, value) in self {
            result[key] = AnyJSON(value)
        }
        return result
    }
}

extension Array where Element == [String: Any] {
    /// Convert array of dictionaries to AnyJSON format for Supabase
    func toAnyJSON() -> [[String: AnyJSON]] {
        return self.map { $0.toAnyJSON() }
    }
}