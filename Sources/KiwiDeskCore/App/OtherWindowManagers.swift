import AppKit

/// A window manager other than KiwiDesk, known by its bundle id
/// (#1882). The name is the product's own, so it is not localized.
public struct OtherWindowManager: Sendable, Hashable {
    public let bundleID: String
    public let name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// Notices another window manager running beside KiwiDesk (#1882):
/// two managers arranging the same windows read as a KiwiDesk bug.
/// Core states which one runs; the GUI words the warning and owns
/// its silencing. Warns only — nothing here stops tiling.
@MainActor
public final class OtherWindowManagerWatch {
    /// The one list of managers KiwiDesk knows. Extend it here.
    public static let known: [OtherWindowManager] = [
        OtherWindowManager(bundleID: "bobko.aerospace", name: "AeroSpace"),
        OtherWindowManager(
            bundleID: "com.amethyst.Amethyst",
            name: "Amethyst"
        ),
        OtherWindowManager(bundleID: "com.barut.OmniWM", name: "OmniWM"),
    ]

    /// Fired at most once per manager per session: at boot for one
    /// already running, at its launch for one starting later.
    public var onDetected: @MainActor (OtherWindowManager) -> Void = {
        _ in
    }

    /// The running apps' bundle ids; a test injects its own.
    var runningBundleIDs: @MainActor () -> [String] = {
        NSWorkspace.shared.runningApplications.compactMap(
            \.bundleIdentifier
        )
    }

    private var announced: Set<String> = []

    public init() {}

    /// Boot's pass over the apps already running.
    func scanRunning() {
        for bundleID in runningBundleIDs() {
            noteLaunch(bundleID: bundleID)
        }
    }

    func noteLaunch(bundleID: String?) {
        guard let bundleID,
            let manager = Self.known.first(where: {
                $0.bundleID == bundleID
            }),
            announced.insert(bundleID).inserted
        else { return }
        onDetected(manager)
    }
}
