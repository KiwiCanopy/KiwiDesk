import Foundation
import Testing

/// The bars' right-click menus' GUI wiring (#1518), which no suite
/// drives: the three hooks Core's rows call, the call that wires
/// them at launch, and the one Keep save both Layout menus take.
@Suite("Bar menu wiring (#1518)")
struct BarMenuWiringTests {
    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/" + path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("every hook a bar menu calls is wired")
    func hooksAreWired() throws {
        let wiring = try squashed("AppDelegate+BarMenus.swift")
        for needle in [
            "core.barMenuHooks.openSettings={[weakself]landingin"
                + "self?.dashboard.show(landing:landing)}",
            "core.barMenuHooks.keepLayout={[weakself]in"
                + "self?.keepLayoutInProfile()}",
        ] {
            #expect(wiring.contains(needle), Comment(rawValue: needle))
        }
    }

    /// Both Layout menus' Keep rows take one save, so a failure is
    /// reported the one way, and the wiring runs at launch.
    @Test("the launch wires the menus and one Keep save serves both")
    func launchWiresOneSave() throws {
        let delegate = try squashed("AppDelegate.swift")
        #expect(delegate.contains("wireBarMenus()"))
        #expect(
            delegate.contains(
                "statusItem.onSaveLayoutToProfile={[weakself]in"
                    + "self?.keepLayoutInProfile()}"
            )
        )
    }
}
