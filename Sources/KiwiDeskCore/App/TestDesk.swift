import Foundation

/// The QA lever that points a process at a test desk (#3121).
/// `KIWIDESK_HOME=<root>` puts the config folder at
/// `<root>/config` and the machine folder at `<root>/machine`,
/// and keeps the instance off the owner's defaults domain
/// (`AppDefaults`), LaunchAgent, login item and updater. Unset,
/// every path is the default one.
///
/// Read once per process, here only: the app and the CLI must
/// agree on one root. The instance lock stays the default one.
public enum TestDesk {
    public static let variable = "KIWIDESK_HOME"
    /// The defaults suite a test desk reads and writes.
    public static let defaultsSuite = "com.kiwicanopy.kiwidesk.testdesk"

    /// This process's root, nil for a normal launch.
    public static let root: URL? = root(
        in: ProcessInfo.processInfo.environment
    )

    public static var isActive: Bool { root != nil }

    /// The root `environment` names; an empty value is unset.
    static func root(in environment: [String: String]) -> URL? {
        guard let path = environment[variable], !path.isEmpty
        else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL
    }

    static func configDirectory(under root: URL) -> URL {
        root.appendingPathComponent("config", isDirectory: true)
    }

    static func machineDirectory(under root: URL) -> URL {
        root.appendingPathComponent("machine", isDirectory: true)
    }

    /// Why `verb` is refused on a test desk, nil if it may run:
    /// the service and the login item would start the bundle
    /// later without the variable, on the owner's folders.
    public static func refusal(
        _ verb: String,
        active: Bool = isActive
    ) -> String? {
        guard active else { return nil }
        return "KiwiDesk: \(verb) is refused while \(variable) is set"
    }
}
