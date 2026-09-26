import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A park retires the layout's open size ask (#1694). Device
/// capture 2026-09-26: a boot retile asked a monocle window for
/// the full frame, then the restore made its Space inactive and
/// the park held it at its old, smaller size — and the learner
/// read every parked echo against the cancelled ask, confirming
/// a false maximum the monocle then drew.
@Suite("A park supersedes the open size ask")
@MainActor
struct StashSupersedesAskTests {
    private static let bounds = CGRect(
        x: 0,
        y: 25,
        width: 1728,
        height: 1060
    )
    private static let asked = CGSize(width: 1716, height: 1033)
    private static let parked = CGSize(width: 887, height: 502)

    private static func window() -> ManagedWindow {
        ManagedWindow(
            id: WindowID(1),
            pid: 100,
            appName: "Ghostty",
            title: "~",
            frame: CGRect(origin: .zero, size: parked)
        )
    }

    /// The captured sequence: ask, park, then two settled
    /// readings at the parked size.
    private static func learnAfterPark(
        parks: Bool
    ) -> (candidate: Bool, confirmed: Bool) {
        let engine = TilingEngine()
        let window = window()
        engine.boundLearner.recordAsk(window.id, size: asked)
        if parks {
            engine.stash(
                window,
                in: bounds,
                corner: .bottomLeft,
                force: true,
                capturesOriginal: false
            )
        }
        var confirmed = false
        for _ in 0..<2 {
            confirmed =
                engine.observeEchoAnswer(
                    window.id,
                    size: parked,
                    settledRead: true
                ).confirmed || confirmed
        }
        return (
            engine.candidateSizeBound(for: window.id) != nil,
            confirmed
        )
    }

    /// The control: without a park the same readings DO confirm,
    /// so the clause below measures the park, not a learner that
    /// never learns.
    @Test("Unparked, the readings confirm a bound")
    func controlConfirms() {
        #expect(Self.learnAfterPark(parks: false).confirmed)
    }

    @Test("Parked, the readings answer nothing")
    func parkedLearnsNothing() {
        let result = Self.learnAfterPark(parks: true)
        #expect(!result.confirmed)
        #expect(!result.candidate)
    }

    /// A window already at its corner is still parked: the
    /// early return must not keep the old ask alive.
    @Test("An already-parked window retires the ask too")
    func alreadyParkedRetires() {
        let engine = TilingEngine()
        var window = Self.window()
        window.frame = TilingEngine.stashFrame(
            window.frame,
            in: Self.bounds,
            corner: .bottomLeft
        )
        engine.boundLearner.recordAsk(window.id, size: Self.asked)
        engine.stash(
            window,
            in: Self.bounds,
            corner: .bottomLeft,
            force: false,
            capturesOriginal: false
        )
        for _ in 0..<2 {
            _ = engine.observeEchoAnswer(
                window.id,
                size: Self.parked,
                settledRead: true
            )
        }
        // Neither a standing candidate nor a promoted bound: a
        // confirmation consumes its candidate, so both are read.
        #expect(engine.candidateSizeBound(for: window.id) == nil)
        #expect(engine.boundLearner.bound(for: window.id) == nil)
    }

    /// Learned entries survive a park: only the question retires.
    @Test("A park keeps what was learned")
    func learnedSurvives() {
        let engine = TilingEngine()
        let window = Self.window()
        engine.boundLearner.recordAsk(window.id, size: Self.asked)
        for _ in 0..<2 {
            _ = engine.observeEchoAnswer(
                window.id,
                size: Self.parked,
                settledRead: true
            )
        }
        let learned = engine.boundLearner.bound(for: window.id)
        #expect(learned != nil)
        engine.stash(
            window,
            in: Self.bounds,
            corner: .bottomLeft,
            force: true,
            capturesOriginal: false
        )
        #expect(engine.boundLearner.bound(for: window.id) == learned)
    }
}
