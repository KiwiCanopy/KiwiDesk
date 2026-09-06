import Foundation
import Testing

@testable import KiwiDesk

/// The app list reaches a folder deep, and stops there (#1279).
///
/// A flat scan skipped every directory that is not itself a
/// bundle, which silently cost the picker all of
/// `/System/Applications/Utilities` — Terminal, Activity Monitor,
/// Console, Disk Utility — so reaching one of those meant knowing
/// its bundle identifier.
///
/// Both bounds are asserted, and the second is narrower than it
/// looks: a real bundle keeps its nested apps under `Contents`,
/// deeper than this walk reaches at all, so skipping a `.app`
/// buys a spared directory read rather than a correctness fix.
/// The fixture puts one directly inside the host to exercise the
/// skip at the only depth that can reach it (`guard-prover`
/// found the first fixture unable to tell the two apart).
@Suite("App scan depth")
struct AppScanDepthTests {
    /// A root laid out like the real ones: a top-level app, one
    /// in a plain subfolder, and one nested INSIDE a bundle.
    private func fixture() throws -> URL {
        let root = URL(
            fileURLWithPath: NSTemporaryDirectory()
        )
        .appendingPathComponent("kiwi-scan-\(UUID().uuidString)")
        let manager = FileManager.default
        for path in [
            "Top.app",
            "Utilities/Nested.app",
            "Host.app/Inner.app",
        ] {
            try manager.createDirectory(
                at: root.appendingPathComponent(path),
                withIntermediateDirectories: true
            )
        }
        return root
    }

    /// Both bounds at once, over the shipped walk.
    @Test("a subfolder app is found; one inside a bundle is not")
    func scanReachesOneFolderDeepOnly() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let found = KeybindingCatalog.appPathsForTesting(
            under: root.path
        )
        .map { URL(fileURLWithPath: $0).lastPathComponent }
        #expect(
            found.contains("Top.app"),
            Comment(
                rawValue:
                    "the walk lost the top level: \(found)"
            )
        )
        #expect(
            found.contains("Nested.app"),
            Comment(
                rawValue:
                    "an app one folder deep is invisible again — "
                    + "that is Terminal and Activity Monitor, "
                    + "which live in Utilities: \(found)"
            )
        )
        #expect(
            !found.contains("Inner.app"),
            Comment(
                rawValue:
                    "the walk read a bundle's own contents — a "
                    + "host's nested apps are its implementation, "
                    + "not apps a user binds: \(found)"
            )
        )
    }
}
