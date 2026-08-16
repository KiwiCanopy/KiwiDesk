import Foundation

/// The pieces `KiwiCore.init` builds before it can call
/// `bootstrapCoreServices()`.
///
/// Split out because a class's designated initializer must live
/// in the main declaration, so `KiwiCore.swift` is the one file
/// that cannot shed weight by moving a method — it is a property
/// bag plus this one function, and it reached §2.1's 350-line
/// ceiling exactly (#836's flag was the line that crossed it).
/// Static helpers can live in an extension; the `init` calling
/// them cannot.
///
/// Each helper takes the resolved directory rather than reading
/// it back off `self`: the initializer needs them all before the
/// stored properties are assigned.
extension KiwiCore {
    /// `~/.config/KiwiDesk/` unless the caller names its own.
    /// `makeTestCore` always names one — a bare `KiwiCore()`
    /// would otherwise read and write the developer's live
    /// config, which is half of what `MachineTouchTests` pins.
    static func resolveConfigDirectory(_ override: URL?) -> URL {
        override
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KiwiDesk")
    }

    static func makeSocketServer(in directory: URL) -> SocketServer {
        SocketServer(
            path:
                directory
                .appendingPathComponent("KiwiDesk.sock").path
        )
    }

    static func makeProfileManager(
        in directory: URL
    ) -> ProfileManager {
        ProfileManager(
            directory: directory.appendingPathComponent("profiles")
        )
    }
}
