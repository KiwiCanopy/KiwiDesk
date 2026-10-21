import Foundation
import KiwiDeskCore

/// The socket verbs whose path argument is a file the caller
/// names (#2517). The app's working directory is not the
/// caller's, so a relative path is resolved here, against the
/// shell's, before it is sent; Core refuses one that arrives
/// relative.
enum CLIPathArguments {
    static let verbs: Set<String> = [
        KiwiCore.exportSetupCommand,
        KiwiCore.restoreSetupCommand,
    ]

    /// `arguments` with the first non-flag one made absolute
    /// against `directory`, for a verb that takes a path.
    static func resolved(
        _ arguments: [String],
        command: String,
        directory: String = FileManager.default.currentDirectoryPath
    ) -> [String] {
        guard verbs.contains(command),
            let index = arguments.firstIndex(where: {
                !$0.hasPrefix("--")
            })
        else { return arguments }
        var resolved = arguments
        let path = (arguments[index] as NSString).expandingTildeInPath
        resolved[index] =
            path.hasPrefix("/")
            ? path
            : URL(fileURLWithPath: directory)
                .appendingPathComponent(path)
                .standardizedFileURL.path
        return resolved
    }
}
