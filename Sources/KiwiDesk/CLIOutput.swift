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
}
