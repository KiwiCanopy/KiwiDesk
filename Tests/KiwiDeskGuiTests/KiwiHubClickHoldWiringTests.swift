import Foundation
import Testing

@testable import KiwiDesk

/// A close a click on KiwiHub made keeps the panel up, unseen, for
/// the rest of the double-click interval, and a leaving panel drops
/// every click (#3209). `DesktopsClickTests` holds the arithmetic;
/// this holds the wiring, which no headless panel reaches.
@Suite("KiwiHub click hold wiring")
struct KiwiHubClickHoldWiringTests {
    private static func squash(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/" + path)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the close reads the hold at the press and hands it on")
    func closeReadsTheHold() throws {
        let controller = try Self.squash("Jump/JumpPanelController.swift")
        #expect(
            controller.contains(
                "lethold=PanelPresence.clickHoldNow(on:panel)"
                    + "handBack.release(distrusting:distrusting){"
                    + "[weakself]inself?.fadeOut(holdUnseen:hold)}"
            )
        )
        #expect(
            controller.contains(
                "panel.leaving={[weakself]inself?.presence.leaving??false}"
            )
        )
        #expect(controller.contains("panel.alphaValue=1"))
    }

    @Test("the fade holds the panel unseen past its own length")
    func fadeHolds() throws {
        let presence = try Self.squash("PanelEntrance.swift")
        #expect(PanelPresence.holdAlpha > 0)
        #expect(
            presence.contains(
                "letrest=holdUnseen-delayguardrest>0else{"
                    + "panel?.orderOut(nil)return}"
                    + "panel?.ignoresMouseEvents=false"
                    + "panel?.alphaValue=Self.holdAlpha"
            )
        )
    }

    @Test("a leaving panel drops its clicks")
    func leavingDropsClicks() throws {
        let panel = try Self.squash("Jump/JumpPanel.swift")
        #expect(panel.contains(".leftMouseDown,.leftMouseUp,"))
        #expect(panel.contains("ifleaving(){"))
        let arm = try #require(panel.range(of: "ifleaving(){"))
        let rest = panel[arm.upperBound...]
        let close = try #require(rest.range(of: "return}"))
        let superCall = try #require(rest.range(of: "super.sendEvent("))
        #expect(close.lowerBound < superCall.lowerBound)
    }
}
