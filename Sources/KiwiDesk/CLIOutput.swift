import Foundation
import KiwiDeskCore

/// Renders command response payloads for stdout.
enum CLIOutput {
    /// Encodes `data` with sorted keys (#1034), pretty-printed if requested.
    static func render(
        _ data: JSONValue,
        pretty: Bool
    ) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting =
            pretty ? [.sortedKeys, .prettyPrinted] : [.sortedKeys]
        guard let encoded = try? encoder.encode(data) else {
            return nil
        }
        return String(data: encoded, encoding: .utf8)
    }

    /// Whether stdout is connected to a terminal.
    static var stdoutIsTerminal: Bool {
        isatty(FileHandle.standardOutput.fileDescriptor) == 1
    }

    /// One human line per `declared_in` source a payload carries
    /// (#1509), for stderr — stdout stays the JSON a script
    /// parses. Empty for a payload without the key.
    static func declaredInNotes(_ data: JSONValue) -> [String] {
        guard case .object(let fields) = data,
            case .array(let sources)? = fields["declared_in"]
        else { return [] }
        return sources.compactMap(\.stringValue).map(note)
    }

    private static func note(for source: String) -> String {
        let profile = "profile:"
        if source.hasPrefix(profile) {
            let name = source.dropFirst(profile.count)
            return "removed from the live layout but still in "
                + "saved profile \"\(name)\" — "
                + "save the profile to make this durable"
        }
        let standard = "standard:"
        if source.hasPrefix(standard) {
            let name = source.dropFirst(standard.count)
            return "still composed by the built-in \"\(name)\" "
                + "standard — save a profile to make this durable"
        }
        switch source {
        case "init.lua":
            return "still created by init.lua — "
                + "remove the call that creates it"
        default:
            return "still declared in \(source)"
        }
    }
}
