import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The #1882 alert's silencing and the wiring no fixture reaches:
/// the boot scan, the launch's bundle id and the GUI hook.
@MainActor
@Suite("Other window manager alert (#1882)")
struct OtherWindowManagerAlertTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private let aerospace = OtherWindowManager(
        bundleID: "bobko.aerospace",
        name: "AeroSpace"
    )
    private let amethyst = OtherWindowManager(
        bundleID: "com.amethyst.Amethyst",
        name: "Amethyst"
    )

    private func scratchDefaults() -> UserDefaults {
        let name = "kiwi-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("silencing holds for that manager alone")
    func silenceIsPerManager() {
        let defaults = scratchDefaults()
        #expect(!OtherWindowManagerSilence.isSilenced(aerospace, in: defaults))
        OtherWindowManagerSilence.silence(aerospace, in: defaults)
        OtherWindowManagerSilence.silence(aerospace, in: defaults)
        #expect(OtherWindowManagerSilence.isSilenced(aerospace, in: defaults))
        #expect(!OtherWindowManagerSilence.isSilenced(amethyst, in: defaults))
        #expect(
            defaults.stringArray(forKey: OtherWindowManagerSilence.key)
                == [aerospace.bundleID]
        )
    }

    @Test("boot scans the running apps")
    func bootScans() throws {
        let body = try SourceScan.functionBody(
            of: "finishBoot",
            in: "KiwiCore+Boot.swift",
            under: "App"
        )
        #expect(body.contains("otherWindowManagers.scanRunning()"))
    }

    @Test("the launch arm carries the bundle id")
    func launchCarriesBundleID() throws {
        let body = try SourceScan.functionBody(
            of: "appLaunched",
            in: "EventLoop+Apps.swift",
            under: "Events"
        )
        #expect(body.contains("bundleID: app.bundleIdentifier"))
    }

    @Test("the app presents the alert for a detection")
    func appWiresTheAlert() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        #expect(source.contains("core.otherWindowManagers.onDetected"))
        #expect(source.contains("OtherWindowManagerAlert.present(for:"))
    }
}
