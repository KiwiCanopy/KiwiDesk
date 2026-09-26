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

    /// The frame-set doors retire the ask for every caller that
    /// is not the layout loop — a float seed's restore, a boot
    /// snapshot restore — so the fix does not live in `stash`
    /// alone.
    @Test(
        "Any non-layout frame retires the ask",
        arguments: [false, true]
    )
    func frameDoorsRetire(animated: Bool) {
        let engine = TilingEngine()
        let window = Self.window()
        engine.boundLearner.recordAsk(window.id, size: Self.asked)
        let seeded = CGRect(origin: .zero, size: Self.parked)
        if animated {
            // Truly animated: this path never reaches `setFrame`,
            // so `applyFrame`'s own retire is what it measures.
            engine.applyFrame(
                window.id,
                from: window.frame,
                to: seeded,
                animated: true
            )
            engine.animation.cancel(window: window.id)
        } else {
            engine.setFrame(window.id, seeded)
        }
        for _ in 0..<2 {
            _ = engine.observeEchoAnswer(
                window.id,
                size: Self.parked,
                settledRead: true
            )
        }
        #expect(engine.candidateSizeBound(for: window.id) == nil)
        #expect(engine.boundLearner.bound(for: window.id) == nil)
    }

    /// The loop's own order — frame, then ask — keeps learning:
    /// the door retires the OLD ask before the loop records the
    /// new one.
    @Test("A layout ask after its frame still learns")
    func layoutAskStillLearns() {
        let engine = TilingEngine()
        let window = Self.window()
        engine.applyFrame(
            window.id,
            from: window.frame,
            to: CGRect(origin: .zero, size: Self.asked),
            animated: false
        )
        engine.boundLearner.recordAsk(window.id, size: Self.asked)
        var confirmed = false
        for _ in 0..<2 {
            confirmed =
                engine.observeEchoAnswer(
                    window.id,
                    size: Self.parked,
                    settledRead: true
                ).confirmed || confirmed
        }
        #expect(confirmed)
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

    /// A park inside a corroboration probe's grace (#1439) hands
    /// its issue back, so the return re-sends the probe instead
    /// of waiting forever on an answer no parked echo can give.
    @Test(
        "A park hands an in-flight probe's issue back",
        arguments: [true, false]
    )
    func parkUnissuesProbe(parks: Bool) throws {
        let w = WindowID(7)
        let held = CGSize(width: 720, height: 800)
        let ask = CGSize(width: 500, height: 800)
        var learner = SizeBoundLearner()
        learner.recordAsk(w, size: ask, settledFrom: held)
        learner.observe(w, currentSize: held, settledRead: true)
        let taken = learner.takeCorroborationProbe(
            w,
            current: held,
            target: ask
        )
        let first = try #require(taken)
        learner.recordAsk(w, size: first.size)
        if parks {
            learner.parkRetiresAsk(w)
        } else {
            learner.supersedeAsk(w)
        }
        // The Space returns: the loop asks the anchor's size.
        let again = learner.takeCorroborationProbe(
            w,
            current: held,
            target: ask
        )
        // Parked, the probe is re-sent; a plain retire (the
        // control) leaves it issued and unanswered, so nothing is.
        #expect((again != nil) == parks)
    }

    /// The engine wiring of the probe hand-back: `stash` must take
    /// the probe-aware door, not the plain retire.
    @Test("A park through the engine re-sends the in-flight probe")
    func stashUnissuesProbe() throws {
        let engine = TilingEngine()
        let w = WindowID(7)
        let held = CGSize(width: 720, height: 800)
        let ask = CGSize(width: 500, height: 800)
        engine.boundLearner.recordAsk(w, size: ask, settledFrom: held)
        engine.boundLearner.observe(
            w,
            currentSize: held,
            settledRead: true
        )
        let taken = engine.boundLearner.takeCorroborationProbe(
            w,
            current: held,
            target: ask
        )
        let first = try #require(taken)
        engine.boundLearner.recordAsk(w, size: first.size)
        let window = ManagedWindow(
            id: w,
            pid: 100,
            appName: "App",
            title: "Doc",
            frame: CGRect(origin: CGPoint(x: 200, y: 200), size: held)
        )
        engine.stash(
            window,
            in: Self.bounds,
            corner: .bottomLeft,
            force: true,
            capturesOriginal: false
        )
        let again = engine.boundLearner.takeCorroborationProbe(
            w,
            current: held,
            target: ask
        )
        #expect(again != nil)
    }
}
