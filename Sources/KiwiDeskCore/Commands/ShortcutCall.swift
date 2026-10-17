import Foundation

/// The Lua a shortcut built by `shortcut.set` runs (#1685 ▸ Ruling
/// 6c): one call of a command `run` could send — Lua registers it
/// and it is not destructive — spelled as `APIReference.luaFunction`
/// calls it, with literal arguments of the kinds its record names,
/// so a shortcut an AI app binds can never run a shell command or
/// other Lua. A verb that writes shortcuts is never bound.
enum ShortcutCall {
    struct Refusal: Error {
        let reason: String
    }

    static func lua(
        _ name: String,
        _ args: [JSONValue]
    ) -> Result<String, Refusal> {
        guard let entry = APIReference.entry(named: name),
            entry.channel == .both, entry.command != nil,
            !APIReference.isDestructive(entry), entry.group != "shortcut"
        else {
            return .failure(Refusal(reason: "\(name) cannot be bound"))
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
        for (value, argument) in zip(args, arguments) {
            guard fits(value, argument.kind), let literal = literal(value)
            else {
                return .failure(
                    Refusal(
                        reason: "\(argument.name) takes a "
                            + argument.kind.wireName
                    )
                )
            }
            literals.append(literal)
        }
        let function = APIReference.luaFunction(of: entry)
        return .success("\(function)(\(literals.joined(separator: ", ")))")
    }

    /// Whether `value` is a literal of `kind` as the command's
    /// decoder reads it.
    static func fits(_ value: JSONValue, _ kind: APIArgumentKind) -> Bool {
        switch (kind, value) {
        case (.boolean, .bool):
            return true
        case (.number, .number), (.desktop, .number), (.window, .number):
            return true
        case (.integer, .number(let number)):
            return number == number.rounded()
        case (.text, .string), (.color, .string):
            return true
        case (.space, .string), (.space, .number):
            return true
        case (.choice(let choice), .string(let text)):
            return choice.values.contains(text)
        default:
            return false
        }
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
