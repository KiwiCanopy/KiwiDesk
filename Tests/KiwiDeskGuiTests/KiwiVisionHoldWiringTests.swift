import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A lens's delayed clear reaches the user through wiring no
/// fixture constructs (#2103 rulings 12, 42a): the press fan-out
/// ends the hold on a click, every re-draw judges the hold before
/// its sync, and VoiceOver hears each hold's reminder once,
/// without its emoji. Pinned where each lives.
@Suite("KiwiVision hold is wired")
struct KiwiVisionHoldWiringTests {
    private func flat(_ path: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        return try SourceScan.strippedSource(
            at: root.appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }

    @Test("a press reaches the hold after the press stamp")
    func pressEndsTheHold() throws {
        let boot = try flat(
            "Sources/KiwiDeskCore/App/KiwiCore+BootSeams.swift"
        )
        #expect(
            boot.contains(
                "self?.stampLeftClick(at:GeometryUtils.axPoint(point))"
                    + "self?.visionPressed()"
            )
        )
    }

    @Test("every re-draw judges the hold ahead of its request")
    func redrawJudgesTheHold() throws {
        let vision = try flat(
            "Sources/KiwiDeskCore/App/KiwiCore+Vision.swift"
        )
        #expect(
            vision.contains(
                "letfocus=visionTarget()"
                    + "settleVisionHold(target:focus.target)"
                    + "varrequest=visionRequest("
                    + "refreshingList:reassertOrder,focus:focus)"
            )
        )
    }

    @Test("the app delegate announces each hold's reminder")
    func delegateAnnouncesTheHold() throws {
        let delegate = try flat(
            "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
        )
        #expect(delegate.contains("core.vision.onHold={ownin"))
        #expect(
            delegate.contains(
                ".announcement:Self.spokenReminder(reminder)"
            )
        )
    }

    /// A stop releases the hold's pill before the plates go, since
    /// a hold pill has no timer of its own.
    @Test("a stop ends the hold ahead of the plates")
    func stopEndsTheHold() throws {
        let lifecycle = try flat(
            "Sources/KiwiDeskCore/App/KiwiCore+Lifecycle.swift"
        )
        #expect(
            lifecycle.contains("endVisionHold(restack:false)vision.clear()")
        )
    }

    @Test("VoiceOver reads the reminder without its emoji")
    @MainActor
    func spokenWithoutEmoji() {
        #expect(
            AppDelegate.spokenReminder("🥝 Keep the vision juicy 🥝")
                == "Keep the vision juicy"
        )
        #expect(
            AppDelegate.spokenReminder("Stay 2 more ✍️") == "Stay 2 more"
        )
        #expect(
            AppDelegate.spokenReminder("Écris d'abord") == "Écris d'abord"
        )
    }
}
