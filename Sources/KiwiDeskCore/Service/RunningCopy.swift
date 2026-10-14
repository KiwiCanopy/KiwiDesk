import Foundation

/// The running copy of KiwiDesk as an outside launcher sees it
/// (#1685): the login item and the AI page's setup prompt judge
/// its location, the service LaunchAgent spawns its path. Path
/// checks only, so the main actor may ask (#2094).
public enum RunningCopy {
    /// Where the running copy lives, judged by its bundle path.
    public enum Location: Hashable, Sendable {
        /// Inside an `.app` at a stable path.
        case bundled
        /// A Gatekeeper-translocated read-only copy, whose random
        /// path dies at relaunch.
        case translocated
        /// A bare executable without an `.app` wrapper.
        case bare
    }

    /// The bundle the running copy was started from.
    public static var bundleURL: URL { Bundle.main.bundleURL }

    /// The binary a launcher should spawn.
    public static var executablePath: String {
        Bundle.main.executableURL?.path ?? CommandLine.arguments[0]
    }

    /// Where the running copy lives.
    public static var location: Location {
        location(of: bundleURL)
    }

    /// Where a copy whose bundle is at `url` lives.
    static func location(of url: URL) -> Location {
        guard url.pathExtension == "app" else { return .bare }
        if url.path.contains("/AppTranslocation/") {
            return .translocated
        }
        return .bundled
    }
}
