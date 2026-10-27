import CoreGraphics
import Foundation

/// The input-quiescence gate (#804 ▸ Ruling): an ambient layout
/// pass, and a user call's late tail, wait for the hand to rest.
/// What waits is the PASS, never its frames: a held pass becomes a
/// retile owed, re-run against the state as it is when the hand
/// rests — so a later pass, a cancelled tail, a changed screen or
/// a closed window is judged afresh, and the layout loop records
/// its asks and stamps its placements only for frames it sends. A
/// pass a KiwiDesk control makes right now runs, carrying the debt
/// with it. Asked once, by `KiwiCore.retile`; an owed write holds a
/// pass of its own through the same hold.
///
/// A frame an ambient writer sends outside a pass waits here too,
/// as a WINDOW owed, never a frame (#2627): the write is
/// re-derived when a pass runs, and a drag forgets it.
@MainActor
final class MotionGate {
    /// One owed pass: the strongest of the passes it stands for.
    struct Owed: Equatable {
        var animated: Bool?
        var pass: RetilePass
        var newlyCreatedWindow: WindowID?
        var sizing: BatchSizing
        /// The window changing state this pass (#2676).
        var stateChange: WindowID? = nil

        /// Two held passes as one: the stronger pass, a spring
        /// promise only when both made it (#593), the newest
        /// window, state change and animation choice.
        func merged(with newer: Owed) -> Owed {
            Owed(
                animated: newer.animated ?? animated,
                pass: Self.rank(newer.pass) > Self.rank(pass)
                    ? newer.pass : pass,
                newlyCreatedWindow: newer.newlyCreatedWindow
                    ?? newlyCreatedWindow,
                sizing: sizing == newer.sizing ? sizing : .mayInstantSize,
                stateChange: newer.stateChange ?? stateChange
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

    /// A direct frame write outside a pass, owed for one window
    /// until a pass runs (#2627). Declaration order is precedence:
    /// the payer tries a window's owed writes in this order and
    /// stops at the first that writes.
    enum OwedWrite: CaseIterable {
        /// A detection flip's float placement.
        case floatPlacement
        /// A float's move onto its Space's screen (#2628).
        case reanchor
        /// A replayed snapshot frame (#2626). Last: it is a capture
        /// from before the rest, while the two above are derived
        /// from the state as it is now.
        case restore
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
    /// The owed direct writes, written through `KiwiCore`'s one
    /// `oweAmbientWrite` door and taken by its one payer.
    private(set) var owedWrites: [WindowID: Set<OwedWrite>] = [:]
    private var owedSince: TimeInterval?
    private var armed = false
    private var releasing = false
    private var payingWrites = false
    private var switching = false
    /// Whether a watched switch's pass is running now.
    var isSwitching: Bool { switching }

    /// Runs `body` as a switch the user is watching — a Space or
    /// Desktop switch, a display follow — which never waits:
    /// holding it would split the desk, the bars showing a Space
    /// whose windows are not there (owner ruling 2026-10-06). Boot,
    /// the wake replay and a switch's settle are not switches. A
    /// pass inside also owes no #677 settle probe (#2187).
    func exemptingSwitch(_ body: () -> Void) {
        let outer = switching
        switching = true
        defer { switching = outer }
        body()
    }

    /// The pass to run now — `pass` with any debt merged in, so
    /// what was owed is never lost to a weaker pass — or nil when
    /// it waits.
    func admit(_ pass: Owed) -> Owed? {
        if releasing { return pass }
        let cause = cause()
        let (runs, user) = verdict(cause)
        if runs {
            let run = owed.map { $0.merged(with: pass) } ?? pass
            settle(why: user ? "a user pass" : "the hand rests")
            return run
        }
        hold(pass, cause: cause)
        return nil
    }

    private func hold(_ pass: Owed, cause: MotionCause) {
        owed = owed.map { $0.merged(with: pass) } ?? pass
        if owedSince == nil {
            owedSince = clock()
            onLog("layout held: \(Self.describe(cause))")
        }
        arm()
    }

    /// Whether a pass asked now would wait — `admit`'s verdict,
    /// read without owing anything.
    var holdsNow: Bool {
        !releasing && !payingWrites && !verdict(cause()).runs
    }

    /// Owes `write` for `id` while the gate holds, holding a pass of
    /// its own when none is owed, so the release that pays it is
    /// armed; returns whether it owed.
    func owe(_ write: OwedWrite, for id: WindowID) -> Bool {
        guard holdsNow else { return false }
        owedWrites[id, default: []].insert(write)
        if owed == nil { hold(Self.bareEvent, cause: cause()) }
        return true
    }

    /// The pass a write owed alone holds: an event pass with no
    /// window and no promise.
    private static let bareEvent = Owed(
        animated: nil,
        pass: .event,
        newlyCreatedWindow: nil,
        sizing: .mayInstantSize
    )

    /// Hands every owed write to `pay`, in precedence order, until
    /// one writes (`pay` returns whether it did) — inside a scope
    /// where nothing holds, so a payment writes rather than owing
    /// again.
    func payWrites(_ pay: (WindowID, OwedWrite) -> Bool) {
        let due = owedWrites
        owedWrites = [:]
        payingWrites = true
        defer { payingWrites = false }
        for (id, writes) in due {
            for write in OwedWrite.allCases where writes.contains(write) {
                if pay(id, write) { break }
            }
        }
    }

    /// A drag owns the window's frame from its first move on.
    func forgetWrite(for id: WindowID) {
        owedWrites[id] = nil
    }

    /// Told of every frame the engine writes: one the user's own
    /// act writes owns the window, so its owed write is forgotten —
    /// a late tail's too, which still carries that act though its
    /// pass waits. A pass pays its debt before it lays out, so its
    /// own writes forget none.
    func frameWritten(_ id: WindowID) {
        if case .user = cause() { owedWrites[id] = nil }
    }

    /// Forgets every window's owed `write`: what it was owed from
    /// is gone.
    func forgetWrites(_ write: OwedWrite) {
        for id in owedWrites.keys {
            owedWrites[id]?.remove(write)
            if owedWrites[id]?.isEmpty == true { owedWrites[id] = nil }
        }
    }

    /// A native tab switch re-keys the window its write is owed for.
    func rekeyWrite(old: WindowID, new: WindowID) {
        guard let write = owedWrites.removeValue(forKey: old) else {
            return
        }
        owedWrites[new] = write
    }

    /// Forgets the debt: KiwiDesk is stopping, and the gather owns
    /// the motion now.
    func dropAll() {
        owed = nil
        owedWrites = [:]
        owedSince = nil
    }

    /// Whether a pass under `cause` runs now, and whether it runs
    /// as the user's — the one verdict `admit` and `holdsNow` read.
    private func verdict(
        _ cause: MotionCause
    ) -> (runs: Bool, user: Bool) {
        var user = switching
        if case .user(_, late: false) = cause { user = true }
        let rests = quiescence.admits(
            heldFor: owedSince.map { clock() - $0 }
        )
        return (user || rests, user)
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
