import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// What a lens never holds (#2103 rulings 14, 33) and what the hold
/// says (ruling 42a): Never dimmed apps, system and overlay
/// windows, the clear window's own dialogs and KiwiDesk's own
/// windows land clear; a hold is heard once with the lens's
/// reminder, a blank one taking the default.
@Suite("KiwiVision lens hold exemptions", .serialized)
@MainActor
struct KiwiVisionHoldExemptionTests {
    private typealias F = VisionHoldFixture
    private let extra = WindowID(9)

    @Test("the pure verdict: every exemption stands a landing down")
    func verdict() {
        let left = VisionHold.Landing(leftOut: true)
        #expect(VisionHold.begins(left))
        #expect(!VisionHold.begins(VisionHold.Landing(leftOut: false)))
        let exemptions: [WritableKeyPath<VisionHold.Landing, Bool>] = [
            \.neverDimmed, \.overlay, \.own, \.dialogOfClear, \.clicked,
        ]
        for exemption in exemptions {
            var landing = left
            landing[keyPath: exemption] = true
            #expect(!VisionHold.begins(landing))
        }
    }

    @Test("a Never dimmed app's window lands clear")
    func neverDimmedLandsClear() {
        let (core, _) = F.core()
        core.execute(
            "kiwivision.set_never_dimmed",
            args: [.string("test.kiwi.other")]
        )
        F.focus(core, F.stranger)
        #expect(core.vision.hold == nil)
    }

    @Test("a transient overlay or raised-layer window lands clear")
    func overlaysLandClear() {
        let popup = WindowID(10)
        var palette = F.window(extra, 900_109, "test.kiwi.palette", "")
        palette.isTransientOverlay = true
        var menu = F.window(popup, 900_111, "test.kiwi.menu", "")
        menu.isRaisedLayer = true
        let (core, _) = F.core(windows: [palette, menu])
        F.focus(core, extra)
        #expect(core.vision.hold == nil)
        F.focus(core, popup)
        #expect(core.vision.hold == nil)
    }

    @Test("the clear window's own dialog lands clear")
    func dialogOfClearLandsClear() {
        // A titled member: only "Draft" stays clear, so its app's
        // "Save" dialog is left out, yet never held.
        var dialog = F.window(extra, F.notes, "test.kiwi.notes", "Save")
        dialog.subrole = "AXDialog"
        let (core, _) = F.core(
            lens: [
                "titles": .object([
                    "test.kiwi.notes": .array([.string("Draft")])
                ])
            ],
            windows: [dialog]
        )
        F.focus(core, F.member)
        F.focus(core, extra)
        #expect(core.vision.hold == nil)
        // The same dialog reached from a stranger's window is held.
        F.focus(core, F.stranger)
        F.focus(core, extra)
        #expect(core.vision.hold?.window == extra)
    }

    @Test("KiwiDesk's own window lands clear")
    func ownWindowLandsClear() {
        var own = F.window(extra, 900_110, "test.kiwi.self", "Settings")
        own.carriesOwnMark = true
        let (core, _) = F.core(windows: [own])
        F.focus(core, extra)
        #expect(core.vision.hold == nil)
    }

    @Test("a hold is heard once with the lens's reminder")
    func reminderIsHeard() {
        LocalizationManager.shared.select("en")
        let (core, _) = F.core(lens: ["reminder": .string("Stay here")])
        var heard: [String?] = []
        core.vision.onHold = { heard.append($0) }
        F.focus(core, F.stranger)
        core.updateVision()
        #expect(heard == ["Stay here"])
        #expect(core.visionReminder == "Stay here")
    }

    @Test("a blank reminder shows the default")
    func blankReminderShowsTheDefault() {
        LocalizationManager.shared.select("en")
        let (core, _) = F.core(lens: ["reminder": .string("  ")])
        var heard: [String?] = []
        core.vision.onHold = { heard.append($0) }
        F.focus(core, F.stranger)
        #expect(heard == [nil])
        #expect(core.visionReminder == "🥝 Keep the vision juicy 🥝")
    }

    @Test("at a delay of 0 nothing is heard")
    func noDelayIsSilent() {
        let (core, _) = F.core(lens: ["clear_delay": .number(0)])
        var heard: [String?] = []
        core.vision.onHold = { heard.append($0) }
        F.focus(core, F.stranger)
        #expect(heard.isEmpty)
    }

    /// The pill a hold shows sits centred on its window and stays
    /// until released, where a refusal's sits at the top.
    @Test("the hold pill is centred on its window")
    func holdPillIsCentred() throws {
        let overlay = SizeLimitOverlay()
        let frame = CGRect(x: 200, y: 200, width: 800, height: 600)
        #expect(overlay.hold(window: 1, frame: frame, text: "Wait"))
        let pill = try #require(overlay.pillForTest(1))
        let flipped = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(abs(pill.panel.midX - flipped.midX) < 1)
        #expect(abs(pill.panel.midY - flipped.midY) < 1)
        // It follows the window when the window moves.
        let moved = frame.offsetBy(dx: 120, dy: 0)
        #expect(overlay.hold(window: 1, frame: moved, text: "Wait"))
        let after = try #require(overlay.pillForTest(1))
        #expect(abs(after.panel.midX - (flipped.midX + 120)) < 1)
    }

    @Test("a hold pill and a refusal pill never share a slot")
    func holdPillHasItsOwnOverlay() {
        let (core, _) = F.core()
        #expect(core.borders.holdPillOverlay !== core.borders.sizeLimitOverlay)
    }
}
