import Foundation

/// The Lua a shortcut built by `shortcut.set` runs (#1685 ▸ Ruling
/// 6c): one call of a command `run` could send — Lua registers it,
/// it is not destructive, not Lua- or CLI-only and not a write of
/// the shortcuts themselves — with literal arguments only, so a
/// shortcut an AI app binds can never run a shell command or other
/// Lua.
enum ShortcutCall {
    struct Refusal: Error {
        let reason: String
    }

    static func lua(
        _ name: String,
        _ args: [JSONValue]
    ) -> Result<String, Refusal> {
        guard let entry = APIReference.entry(named: name),
            entry.channel == .both, entry.command != nil
        else {
            return .failure(Refusal(reason: "\(name) cannot be bound"))
        }
        guard !APIReference.isDestructive(entry),
            entry.qualifiedName != KiwiCore.keepSettingsCommand,
            entry.group != "shortcut"
        else {
            return .failure(
                Refusal(reason: "\(entry.qualifiedName) cannot be bound")
            )
        }
        let arguments = entry.record.arguments
        let required = arguments.filter { !$0.isOptional }.count
        guard args.count >= required, args.count <= arguments.count else {
            return .failure(
                Refusal(
                    reason: "\(entry.qualifiedName) takes \(required)"
                        + "–\(arguments.count) arguments"
                )
            )
        }
        var literals: [String] = []
        for value in args {
            guard let literal = literal(value) else {
                return .failure(
                    Refusal(
                        reason: "arguments must be strings, numbers or "
                            + "booleans"
                    )
                )
            }
            literals.append(literal)
        }
        return .success(
            "\(entry.qualifiedName)(\(literals.joined(separator: ", ")))"
        )
    }

    /// A Lua literal for a JSON scalar; nil for anything else.
    static func literal(_ value: JSONValue) -> String? {
        switch value {
        case .bool(let flag):
            return flag ? "true" : "false"
        case .number(let number):
            guard number.isFinite else { return nil }
            return number == number.rounded() && abs(number) < 1e15
                ? String(Int64(number)) : String(number)
        case .string(let text):
            var quoted = "\""
            for scalar in text.unicodeScalars {
                switch scalar {
                case "\\": quoted += "\\\\"
                case "\"": quoted += "\\\""
                case "\n": quoted += "\\n"
                case "\r": quoted += "\\r"
                case "\t": quoted += "\\t"
                default:
                    guard scalar.value >= 0x20 else { return nil }
                    quoted.unicodeScalars.append(scalar)
                }
            }
            return quoted + "\""
        default:
            return nil
        }
    }
}
