import AppKit
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

    @Test("silencing holds for that manager alone")
    func silenceIsPerManager() {
        let name = "kiwi-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
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
        let scan =
            "otherWindowManagers.scanRunning(eventLoop.liveApps("
            + "owners: []).map { ($0.pid, $0.ref.bundleID) })"
        #expect(Self.squashed(body).contains(Self.squashed(scan)))
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
        let detected = """
            core.otherWindowManagers.onDetected = { [weak self] manager in
                OtherWindowManagerAlert.present(for: manager) {
                    self?.core.otherWindowManagers.quit(manager)
                }
            }
            """
        let gone = """
            core.otherWindowManagers.onGone = { manager in
                OtherWindowManagerAlert.close(for: manager)
            }
            """
        for wiring in [detected, gone] {
            #expect(Self.squashed(source).contains(Self.squashed(wiring)))
        }
    }

    /// The hosted panel answers ⌘W and Esc by closing for this
    /// launch; an `NSAlert` window, not `.closable`, would beep at
    /// ⌘W (#1533). It stays up while KiwiDesk is inactive.
    @Test("the alert panel validates and answers Close")
    func panelHonoursClose() {
        let alert = NSAlert()
        alert.layout()
        let panel = OtherWindowManagerAlert.host(alert.window)
        #expect(!panel.styleMask.contains(.closable))
        #expect(!panel.hidesOnDeactivate)
        var dismissed = 0
        panel.onDismiss = { dismissed += 1 }
        let close = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        #expect(panel.validateUserInterfaceItem(close))
        panel.performClose(nil)
        panel.cancelOperation(nil)
        #expect(dismissed == 2)
    }

    @Test("a silenced manager is never presented")
    func silencedIsNotPresented() {
        let name = "kiwi-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(
            OtherWindowManagerAlert.shouldPresent(
                aerospace,
                defaults: defaults
            )
        )
        OtherWindowManagerSilence.silence(aerospace, in: defaults)
        #expect(
            !OtherWindowManagerAlert.shouldPresent(
                aerospace,
                defaults: defaults
            )
        )
    }

    @Test("present asks shouldPresent first")
    func presentIsGated() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/OtherWindowManagerAlert.swift"
            )
        )
        let gate = "guard shouldPresent(manager, defaults: defaults) else"
        #expect(Self.squashed(source).contains(Self.squashed(gate)))
    }

    private static func squashed(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }
}
