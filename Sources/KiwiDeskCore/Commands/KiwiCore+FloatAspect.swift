import CoreGraphics
import Foundation

/// A float whose app holds its aspect ratio, judged from its answers
/// (#2973). AX states no such lock, but a locked app fits a size ask
/// inside the asked box: a one-axis grow lands nowhere and a one-axis
/// shrink moves both axes. `docs/design-decisions.md` has the argument.
extension KiwiCore {
    /// One press being judged. `base` is where the window stood when
    /// it was pressed, read from WindowServer: a spring's target is
    /// what was asked, never what the app showed. `target` is the frame
    /// the press asked for, split and clamped.
    struct FloatAspectAsk {
        let window: WindowID
        let axis: String
        let delta: Double
        let base: CGRect
        let target: CGRect

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
    /// written always gets its answer. A press on the other axis voids
    /// an ask not yet probed, or both axes moving would read as a lock.
    func oweFloatAspectJudgement(_ ask: FloatAspectAsk) {
        guard !deferred.isScheduled(.floatAspect) else {
            if let axis = state.floatAspectAskAxis, axis != ask.axis {
                endFloatAspectJudgement()
            }
            return
        }
        guard state.floatAspects[ask.window]?.isSettled != true,
            FloatResize.aspectAskIsReadable(
                base: ask.base.size,
                asked: ask.target.size,
                horizontal: ask.horizontal
            )
        else { return }
        state.floatAspectAskAxis = ask.axis
        scheduleFloatAspectJudgement(ask)
    }

    private func endFloatAspectJudgement() {
        state.floatAspectAskAxis = nil
        state.floatAspectProbing = nil
        deferred.cancel(.floatAspect)
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
            endFloatAspectJudgement()
            return
        }
        if floatAspectStandsDown {
            scheduleFloatAspectJudgement(ask)
            return
        }
        guard let live = windowServer.readWindowBounds(ask.window) else {
            endFloatAspectJudgement()
            return
        }
        switch FloatResize.aspectAnswer(
            base: ask.base.size,
            answered: live.size,
            horizontal: ask.horizontal
        ) {
        case .fitted:
            lockFloatAspect(ask.window, pid: pid, ratioOf: ask.base)
            endFloatAspectJudgement()
        case .complied:
            fileFloatAspectFree(ask.window, pid: pid, size: live.size)
            endFloatAspectJudgement()
        case .unchanged where ask.delta > 0:
            probeFloatAspect(ask, live: live)
        case .unchanged, .other:
            endFloatAspectJudgement()
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
        state.floatAspectAskAxis = nil
        state.floatAspectProbing = ask.window
        tiler.applyFrame(ask.window, from: live, to: probe, animated: false)
        scheduleFloatAspectProbeAnswer(ask, live: live)
    }

    private func scheduleFloatAspectProbeAnswer(
        _ ask: FloatAspectAsk,
        live: CGRect
    ) {
        deferred.schedule(
            .floatAspect,
            after: .seconds(Self.floatAspectProbeSeconds)
        ) { [weak self] in
            self?.judgeFloatAspectProbe(ask, live: live)
        }
    }

    /// Reads the probe's answer, waiting out a key or a pointer, since
    /// the shrink is owed its verdict. A lock takes the press's step in
    /// proportion, from where the probe left it. A window that refused
    /// the shrink too is fixed, and goes back where the press found it.
    /// Anything else is free of a lock, and takes what the press asked.
    /// A window moved or left in the wait keeps what it has, unjudged.
    func judgeFloatAspectProbe(_ ask: FloatAspectAsk, live: CGRect) {
        guard resizeRoutesAsFloat(ask.window),
            let pid = state.windows[ask.window]?.pid
        else {
            endFloatAspectJudgement()
            return
        }
        // A button down is a hand on it: what it does is the user's.
        if tiler.motionGate.quiescence.buttonsDown() {
            endFloatAspectJudgement()
            return
        }
        if floatAspectStandsDown {
            scheduleFloatAspectProbeAnswer(ask, live: live)
            return
        }
        endFloatAspectJudgement()
        guard let answered = windowServer.readWindowBounds(ask.window)
        else {
            tiler.applyFrame(ask.window, from: live, to: live, animated: false)
            return
        }
        guard
            abs(answered.minX - live.minX) <= FloatResize.answerTolerance,
            abs(answered.minY - live.minY) <= FloatResize.answerTolerance
        else { return }
        let answer = FloatResize.aspectAnswer(
            base: live.size,
            answered: answered.size,
            horizontal: ask.horizontal
        )
        if answer == .unchanged {
            var refused = state.floatAspects[ask.window]?.refusedAxes ?? []
            refused.insert(ask.axis)
            state.floatAspects[ask.window] = .init(
                pid: pid,
                ratio: nil,
                refusedAxes: refused,
                refusedSize: answered.size
            )
            tiler.applyFrame(
                ask.window,
                from: answered,
                to: CGRect(origin: ask.base.origin, size: answered.size),
                animated: false
            )
            return
        }
        guard answer == .fitted else {
            fileFloatAspectFree(ask.window, pid: pid, size: answered.size)
            tiler.applyFrame(
                ask.window,
                from: answered,
                to: ask.target,
                animated: false
            )
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

    /// A press on a refused axis: the size alone, at the frame shown.
    func askRefusedAxis(
        _ id: WindowID,
        from shown: CGRect,
        axis: String,
        delta: Double
    ) {
        var asked = shown
        if axis == "x" {
            asked.size.width = max(shown.width + delta, 1)
        } else {
            asked.size.height = max(shown.height + delta, 1)
        }
        tiler.applyFrame(id, from: shown, to: asked, animated: false)
    }

    /// Free on the pressed axis, keeping any axis already refused.
    private func fileFloatAspectFree(
        _ id: WindowID,
        pid: pid_t,
        size: CGSize
    ) {
        var record = state.floatAspects[id] ?? .init(pid: pid, ratio: nil)
        if record.refusedSize != nil { record.refusedSize = size }
        state.floatAspects[id] = record
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
