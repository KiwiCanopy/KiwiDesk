import CoreGraphics
import Foundation

/// A float whose app holds its aspect ratio, judged from its answers
/// (#2973). AX states no such lock, but a locked app fits a size ask
/// inside the asked box: a one-axis grow lands nowhere and a one-axis
/// shrink moves both axes. `docs/design-decisions.md` has the argument.
extension KiwiCore {
    /// One press being judged. `base` is where the window stood when
    /// it was pressed, read from WindowServer: a spring's target is
    /// what was asked, never what the app showed.
    struct FloatAspectAsk {
        let window: WindowID
        let axis: String
        let delta: Double
        let base: CGRect
        let asked: CGSize

        var horizontal: Bool { axis == "x" }
    }

    /// The small one-axis shrink that proves a lock, in points. It
    /// must outlast `FloatResize.answerTolerance` on the other axis.
    static let floatAspectProbeStep: CGFloat = 12
    /// Wait for a probe's answer, in seconds.
    static let floatAspectProbeSeconds = 0.3

    /// The float `resize` routes to itself: the active Space's focus,
    /// floating and not native full screen. The verb and a judgement
    /// reading the window later ask the same question.
    func resizeRoutesAsFloat(_ id: WindowID) -> Bool {
        guard let space = activeSpace,
            space.focused == id,
            let window = state.windows[id],
            !window.isFullscreen
        else { return false }
        return EffectiveFloat.applies(
            isFloating: window.isFloating,
            mode: space.mode
        )
    }

    /// Arms one judgement. One runs at a time, holding its slot until
    /// it ends and never replaced by a press, so a probe already
    /// written always gets its answer.
    /// An ask inside the tolerance would read as a complying no-op.
    func oweFloatAspectJudgement(_ ask: FloatAspectAsk) {
        let moved =
            ask.horizontal
            ? ask.asked.width - ask.base.width
            : ask.asked.height - ask.base.height
        guard !deferred.isScheduled(.floatAspect),
            state.floatAspects[ask.window] == nil,
            abs(moved) > FloatResize.answerTolerance
        else { return }
        scheduleFloatAspectJudgement(ask)
    }

    private func scheduleFloatAspectJudgement(_ ask: FloatAspectAsk) {
        deferred.schedule(
            .floatAspect,
            after: .seconds(Self.sizeBoundProbeGraceSeconds)
        ) { [weak self] in
            self?.judgeFloatAspect(ask)
        }
    }

    /// A key or a hand on the window: its writes would land on the
    /// probe, and a frame it moves answers nothing. This is the ruled
    /// answer to the motion gate: a probe can't be paid by a later
    /// pass, so the judgement waits instead of owing (#2627).
    private var floatAspectStandsDown: Bool {
        keys.isGliding
            || keys.holdGlide.heldID != nil
            || tiler.motionGate.holdsNow
    }

    /// Reads the press's answer, once the hand has left the window.
    func judgeFloatAspect(_ ask: FloatAspectAsk) {
        guard resizeRoutesAsFloat(ask.window),
            let pid = state.windows[ask.window]?.pid
        else {
            deferred.cancel(.floatAspect)
            return
        }
        if floatAspectStandsDown {
            scheduleFloatAspectJudgement(ask)
            return
        }
        guard let live = windowServer.readWindowBounds(ask.window) else {
            deferred.cancel(.floatAspect)
            return
        }
        switch FloatResize.aspectAnswer(
            base: ask.base.size,
            answered: live.size,
            horizontal: ask.horizontal
        ) {
        case .fitted:
            lockFloatAspect(ask.window, pid: pid, ratioOf: ask.base)
            tiler.animation.recordGlideCommanded(ask.window, frame: live)
            deferred.cancel(.floatAspect)
        case .complied:
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
            deferred.cancel(.floatAspect)
        case .unchanged where ask.delta > 0:
            probeFloatAspect(ask, live: live)
        case .unchanged, .other:
            deferred.cancel(.floatAspect)
        }
    }

    /// A refused grow may be a lock or a fixed size: a shrink tells
    /// them apart, and a slow app's late grow cannot pass for it.
    private func probeFloatAspect(_ ask: FloatAspectAsk, live: CGRect) {
        var probe = live
        if ask.horizontal {
            probe.size.width -= Self.floatAspectProbeStep
        } else {
            probe.size.height -= Self.floatAspectProbeStep
        }
        tiler.applyFrame(ask.window, from: live, to: probe, animated: false)
        deferred.schedule(
            .floatAspect,
            after: .seconds(Self.floatAspectProbeSeconds)
        ) { [weak self] in
            self?.judgeFloatAspectProbe(ask, live: live)
        }
    }

    /// Reads the probe's answer: a lock takes the press's step in
    /// proportion, from where the probe left it. Anything else is free
    /// of a lock, and a window the probe moved takes the size the press
    /// asked for. A window the user moved or left in the wait keeps
    /// what it has, unjudged.
    func judgeFloatAspectProbe(_ ask: FloatAspectAsk, live: CGRect) {
        deferred.cancel(.floatAspect)
        guard resizeRoutesAsFloat(ask.window), !tiler.motionGate.holdsNow,
            let pid = state.windows[ask.window]?.pid
        else { return }
        let asked = CGRect(origin: live.origin, size: ask.asked)
        guard let answered = windowServer.readWindowBounds(ask.window)
        else {
            tiler.applyFrame(ask.window, from: live, to: live, animated: false)
            return
        }
        let answer = FloatResize.aspectAnswer(
            base: live.size,
            answered: answered.size,
            horizontal: ask.horizontal
        )
        guard answer == .fitted else {
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
            if answer != .unchanged {
                tiler.applyFrame(
                    ask.window,
                    from: answered,
                    to: asked,
                    animated: false
                )
            }
            return
        }
        lockFloatAspect(ask.window, pid: pid, ratioOf: live)
        let lost =
            ask.horizontal
            ? live.width - answered.width
            : live.height - answered.height
        _ = resizeFloating(
            ask.window,
            axis: ask.axis,
            delta: ask.delta + lost
        )
    }

    private func lockFloatAspect(
        _ id: WindowID,
        pid: pid_t,
        ratioOf frame: CGRect
    ) {
        guard frame.height > 0 else { return }
        state.floatAspects[id] = .init(
            pid: pid,
            ratio: frame.width / frame.height
        )
        onLog("window \(id.raw) holds its aspect ratio")
    }
}
