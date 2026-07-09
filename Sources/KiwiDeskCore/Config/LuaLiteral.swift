import CoreGraphics
import Foundation

/// Formats Swift values as Lua source literals for the config
/// writer. Deterministic output (stable across runs) so the
/// generated managed block only changes when settings do.
enum LuaLiteral {
    /// Integers print without a decimal point; fractions use
    /// Swift's shortest round-trippable form (`0.5`, `0.62`,
    /// `0.3333333333333333`) so a value survives write→reload
    /// exactly. Non-finite values fall back to `0`.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int(value))
        }
        return value.description
    }

    static func number(_ value: CGFloat) -> String {
        number(Double(value))
    }

    static func bool(_ value: Bool) -> String {
        value ? "true" : "false"
    }

    /// A double-quoted, escaped Lua string.
    static func string(_ value: String) -> String {
        var escaped = ""
        for character in value {
            switch character {
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\n": escaped += "\\n"
            case "\t": escaped += "\\t"
            case "\r": escaped += "\\r"
            default: escaped.append(character)
            }
        }
        return "\"" + escaped + "\""
    }

    /// The exact inverse of `string(_:)`: the value inside a
    /// canonical quoted literal, or nil when `literal` is not
    /// in the form this writer emits (unquoted, an escape this
    /// writer never authors, a dangling backslash). Strict on
    /// purpose — callers use it to recognize *generated* Lua
    /// (#92), never to parse arbitrary hand-written source.
    static func parseString(_ literal: String) -> String? {
        guard literal.count >= 2, literal.hasPrefix("\""),
            literal.hasSuffix("\"")
        else { return nil }
        var value = ""
        var pending = false
        for character in literal.dropFirst().dropLast() {
            if pending {
                switch character {
                case "\\": value.append("\\")
                case "\"": value.append("\"")
                case "n": value.append("\n")
                case "t": value.append("\t")
                case "r": value.append("\r")
                default: return nil
                }
                pending = false
            } else if character == "\\" {
                pending = true
            } else if character == "\"" {
                // A raw quote means the closing quote matched
                // above was not the real terminator.
                return nil
            } else {
                value.append(character)
            }
        }
        return pending ? nil : value
    }

    /// A space identifier: a bare number when numeric (`1`),
    /// otherwise a quoted string (`"mail"`).
    static func space(_ id: SpaceID) -> String {
        if Int(id.raw) != nil { return id.raw }
        return string(id.raw)
    }
}
