import Foundation

/// Preserve metadata we don't understand yet rather than silently dropping it.
indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let bool = try? value.decode(Bool.self) { self = .bool(bool) }
        else if let number = try? value.decode(Decimal.self) { self = .number(number) }
        else if let string = try? value.decode(String.self) { self = .string(string) }
        else if let object = try? value.decode([String: JSONValue].self) { self = .object(object) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }

    func encode(to encoder: any Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let string): try value.encode(string)
        case .number(let number): try value.encode(number)
        case .bool(let bool): try value.encode(bool)
        case .object(let object): try value.encode(object)
        case .array(let array): try value.encode(array)
        case .null: try value.encodeNil()
        }
    }

    /// Recursively checks leaf scalar values for a lowercased search term,
    /// avoiding internal keys or booleans that cause noisy false positives.
    func containsSearchTerm(_ lowercasedQuery: String) -> Bool {
        switch self {
        case .string(let string):
            return string.lowercased().contains(lowercasedQuery)
        case .number(let number):
            return NSDecimalNumber(decimal: number).stringValue.lowercased().contains(lowercasedQuery)
        case .array(let array):
            return array.contains { $0.containsSearchTerm(lowercasedQuery) }
        case .object(let object):
            return object.values.contains { $0.containsSearchTerm(lowercasedQuery) }
        case .bool, .null:
            return false
        }
    }
}
