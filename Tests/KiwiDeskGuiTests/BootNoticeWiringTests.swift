import Foundation
import Testing

/// The slow-boot notice's wiring (#1715): fed from the one
/// `onBootPhaseChange` fan-out, standing down where the ruling
/// says, and told when "What's new" narrates the boot. A guard on
/// the functions alone cannot see a call site that stopped
/// calling them.
@Suite("Slow-boot notice wiring (#1715)")
struct BootNoticeWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent("Sources/KiwiDesk/\(path)")
        )
    }

    @Test("the boot fan-out feeds the notice once")
    func fanOutFeedsTheNotice() throws {
        let delegate = try source("AppDelegate.swift")
        #expect(delegate.occurrences(of: "bootNotice.phase(phase)") == 1)
        #expect(delegate.occurrences(of: "wireBootNotice()") == 1)
    }

    @Test("a narrated relaunch stands the notice down")
    func relaunchStandsDown() throws {
        let whatsNew = try source("AppDelegate+WhatsNew.swift")
        #expect(
            whatsNew.occurrences(
                of: "bootNotice.narratedElsewhere = narrated"
            ) == 1
        )
    }

    @Test("every stand-down and anchor read is wired")
    func readsAreWired() throws {
        let wiring = try source("AppDelegate+BootNotice.swift")
        // Assignment form: a closure built and never assigned
        // must not satisfy the needle.
        for needle in [
            "bootNotice.tourShowing = {",
            "onboardingWindow?.isVisible == true",
            "bootNotice.screenStandsDown = {",
            "core.shelfStandsDown(on: screen)",
            "bootNotice.liquidGlass = {",
            "shortcutPanelLiquidGlass",
            "bootNotice.statusButton = {",
            "statusItem?.anchorButton",
        ] {
            #expect(wiring.occurrences(of: needle) == 1, "\(needle)")
        }
        let controller = try source(
            "BootNotice/BootNoticeController.swift"
        )
        for needle in [
            "narratedElsewhere || tourShowing()",
            "targetScreen().map(screenStandsDown)",
            "timeline.showsAt(now(), standsDown: standsDown())",
            "shown && window.occlusionState.contains(.visible)",
            "let shown = NSMenu.menuBarVisible()",
            "case .hideAt(let at):",
            "self?.hide()",
        ] {
            #expect(controller.occurrences(of: needle) == 1, "\(needle)")
        }
    }
}
