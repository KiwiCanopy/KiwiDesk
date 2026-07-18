import Foundation

/// Schema-free JSON value used by the IPC protocol and command
/// responses.
public indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode(
            [JSONValue].self
        ) {
            self = .array(a)
        } else {
            self = .object(
                try container.decode(
                    [String: JSONValue].self
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let b):
            try container.encode(b)
        case .number(let n):
            try container.encode(n)
        case .string(let s):
            try container.encode(s)
        case .array(let a):
            try container.encode(a)
        case .object(let o):
            try container.encode(o)
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let s):
            return s
        case .number(let n):
            // A whole number prints without the ".0", but only
            // via the Int path when it actually fits — `Int(1e300)`
            // traps (#386), so an out-of-range whole number falls
            // back to the Double formatting.
            if n == n.rounded(), let i = n.finiteInt {
                return String(i)
            }
            return String(n)
        default:
            return nil
        }
    }

    public var numberValue: Double? {
        switch self {
        case .number(let n):
            return n
        case .string(let s):
            return Double(s)
        default:
            return nil
        }
    }

    public var intValue: Int? {
        numberValue?.finiteInt
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let b):
            return b
        case .string("true"), .string("on"):
            return true
        case .string("false"), .string("off"):
            return false
        default:
            return nil
        }
    }
}

extension Double {
    /// Safe `Int` conversion: nil unless the value is finite and
    /// inside `Int`'s range. `Int(1e300)`, `Int(.nan)`, and
    /// `Int(.infinity)` all trap, so any raw `Double → Int` on
    /// caller-supplied config/IPC numbers must route through here
    /// (#386). `Double(Int.max)` rounds up to 2^63, so the upper
    /// bound is a strict `<` — every value it admits is a
    /// representable `Int`.
    public var finiteInt: Int? {
        guard isFinite,
            self >= Double(Int.min),
            self < Double(Int.max)
        else { return nil }
        return Int(self)
    }
}

extension LuaValue {
    /// Bridges Lua arguments into the IPC value space.
    public var jsonValue: JSONValue {
        switch self {
        case .none, .functionRef:
            return .null
        case .bool(let b):
            return .bool(b)
        case .number(let n):
            return .number(n)
        case .string(let s):
            return .string(s)
        case .array(let items):
            return .array(items.map(\.jsonValue))
        case .table(let dict):
            return .object(dict.mapValues(\.jsonValue))
        }
    }
}
