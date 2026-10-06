import CoreGraphics
import Foundation

/// The input-quiescence gate (#804 ▸ Ruling): an ambient layout
/// pass, and a user call's late tail, wait for the hand to rest.
/// What waits is the PASS, never its frames: a held pass becomes a
/// retile owed, re-run against the state as it is when the hand
/// rests — so a later pass, a cancelled tail, a changed screen or
/// a closed window is judged afresh, and the layout loop records
/// its asks and stamps its placements only for frames it sends. A
/// pass a KiwiDesk control makes right now runs, and pays the debt
/// with it. Asked once, by `KiwiCore.retile`.
@MainActor
final class MotionGate {
    /// One owed pass: the strongest of the passes it stands for.
    struct Owed: Equatable {
        var animated: Bool?
        var pass: RetilePass
        var newlyCreatedWindow: WindowID?
        var sizing: BatchSizing

        /// Two held passes as one: the stronger pass, a spring
        /// promise only when both made it (#593), the newest
        /// window and animation choice.
        func merged(with newer: Owed) -> Owed {
            Owed(
                animated: newer.animated ?? animated,
                pass: Self.rank(newer.pass) > Self.rank(pass)
                    ? newer.pass : pass,
                newlyCreatedWindow: newer.newlyCreatedWindow
                    ?? newlyCreatedWindow,
                sizing: sizing == newer.sizing ? sizing : .mayInstantSize
            )
        }

        private static func rank(_ pass: RetilePass) -> Int {
            switch pass {
            case .event: return 0
            case .reissue: return 1
            case .apply: return 2
            }
        }
    }

    let quiescence = InputQuiescence()
    /// The cause of the pass being asked about — the applier's one
    /// reading.
    var cause: @MainActor () -> MotionCause = { .ambient }
    var clock: @MainActor () -> TimeInterval = { 0 }
    /// Re-asks after `delay`; a test drives it by hand.
    var schedule:
        @MainActor (TimeInterval, @escaping @MainActor () -> Void)
            -> Void = { delay, work in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    MainActor.assumeIsolated(work)
                }
            }
    /// Runs the owed pass, now admitted.
    var release: @MainActor (Owed) -> Void = { _ in }
    var onLog: @MainActor (String) -> Void = CoreLog.write

    private(set) var owed: Owed?
    private var owedSince: TimeInterval?
    private var armed = false
    private var releasing = false

    /// Whether this layout pass waits; true means the caller lays
    /// nothing out now. An admitted pass pays any debt, since it
    /// re-derives every frame the owed one would have sent.
    func defers(_ pass: Owed) -> Bool {
        if releasing { return false }
        let cause = cause()
        let heldFor = owedSince.map { clock() - $0 }
        var user = false
        if case .user(_, late: false) = cause { user = true }
        if user || quiescence.admits(heldFor: heldFor) {
            settle(why: user ? "a user pass" : "the hand rests")
            return false
        }
        owed = owed.map { $0.merged(with: pass) } ?? pass
        if owedSince == nil {
            owedSince = clock()
            onLog("layout held: \(Self.describe(cause))")
        }
        arm()
        return true
    }

    /// Forgets the debt: KiwiDesk is stopping, and the gather owns
    /// the motion now.
    func dropAll() {
        owed = nil
        owedSince = nil
    }

    private func arm() {
        guard !armed else { return }
        armed = true
        schedule(InputQuiescence.poll) { [weak self] in
            guard let self else { return }
            self.armed = false
            guard let owed = self.owed else { return }
            let heldFor = self.owedSince.map { self.clock() - $0 }
            guard self.quiescence.admits(heldFor: heldFor) else {
                return self.arm()
            }
            self.settle(why: "the hand rests")
            self.releasing = true
            defer { self.releasing = false }
            self.release(owed)
        }
    }

    /// The debt is paid — by the release, or by an admitted pass.
    private func settle(why: String) {
        guard owed != nil else { return }
        let waited = owedSince.map { clock() - $0 } ?? 0
        owed = nil
        owedSince = nil
        onLog(
            "layout released after \(Int(waited * 1000)) ms (\(why))"
        )
    }

    private static func describe(_ cause: MotionCause) -> String {
        switch cause {
        case .ambient: return "ambient"
        case .user: return "user, late"
        }
    }
}
