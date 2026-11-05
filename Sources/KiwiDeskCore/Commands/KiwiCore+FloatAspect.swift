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

    /// Arms one judgement. One runs at a time, holding its slot until
    /// it ends and never replaced by a press, so a probe already
    /// written always gets its answer. A press on the other axis of
    /// the window asked voids it, or both axes moving would read as a
    /// lock; so does one the other way, which undid what is being asked.
    func oweFloatAspectJudgement(_ ask: FloatAspectAsk) {
        guard !deferred.isScheduled(.floatAspect) else {
            if case .asking(ask.window, let axis, let grows) =
                state.floatAspectFlight,
                axis != ask.axis || grows != (ask.delta > 0)
            {
                endFloatAspectJudgement()
            }
            return
        }
        guard
            FloatResize.aspectAskIsReadable(
                base: ask.base.size,
                asked: ask.target.size,
                horizontal: ask.horizontal
            )
        else { return }
        state.floatAspectFlight = .asking(
            ask.window,
            axis: ask.axis,
            grows: ask.delta > 0
        )
        scheduleFloatAspectJudgement(ask)
    }

    /// macOS has said this window is fixed (#2994): no answer is
    /// owed, and a probe would only write at a window that cannot take
    /// it. A probe already written keeps its slot.
    func endFloatAspectAsk(of id: WindowID) {
        guard case .asking(id, _, _) = state.floatAspectFlight else { return }
        endFloatAspectJudgement()
    }

    private func endFloatAspectJudgement() {
        state.floatAspectFlight = nil
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

    /// A key or a pointer in use: a key's writes would land on the
    /// probe, and a frame a hand moves answers nothing. The ruled
    /// answer to the motion gate, since no later pass can re-derive a
    /// probe (`state-and-layout.md`).
    private var floatAspectStandsDown: Bool {
        keys.isGliding
            || keys.holdGlide.heldID != nil
            || tiler.motionGate.holdsNow
    }

    /// Reads the press's answer, once the hand has left the window. A
    /// window that has left where it stood, where the press sent it,
    /// where its answer puts it (`SizeLedWrite`, #2981) and where the
    /// last write sent it was moved by a hand, which its frames from
    /// before the wait must not undo.
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
        guard let live = windowServer.readWindowBounds(ask.window),
            FloatResize.sameOrigin(live, ask.base)
                || FloatResize.sameOrigin(live, ask.target)
                || FloatResize.sameOrigin(
                    live,
                    CGRect(
                        origin: SizeLedWrite.origin(
                            asked: ask.target,
                            anchor: ask.base,
                            answer: live.size
                        ),
                        size: live.size
                    )
                )
                || tiler.placements.recent(ask.window).map({
                    FloatResize.sameOrigin(live, $0)
                }) == true
        else {
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
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
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
        state.floatAspectFlight = .probing(ask.window)
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
    /// proportion, from where the probe left it. Anything else holds no
    /// lock: a window that took the probe takes the size the press
    /// asked, where it stands, and one that refused it too is left as
    /// it is, a fixed-size window. One with no answer
    /// goes back where the probe found it. A window moved, left or held
    /// in the wait
    /// keeps what it has, unjudged.
    func judgeFloatAspectProbe(_ ask: FloatAspectAsk, live: CGRect) {
        guard resizeRoutesAsFloat(ask.window),
            !tiler.motionGate.quiescence.buttonsDown(),
            let pid = state.windows[ask.window]?.pid
        else {
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
        guard FloatResize.sameOrigin(answered, live) else { return }
        switch FloatResize.aspectAnswer(
            base: live.size,
            answered: answered.size,
            horizontal: ask.horizontal
        ) {
        case .fitted:
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
        case .unchanged:
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
        case .complied, .other:
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
            tiler.applyFrame(
                ask.window,
                from: answered,
                // The press's split, from where the window stands now:
                // its size-led write held the origin (#2981).
                to: CGRect(
                    x: answered.minX + ask.target.minX - ask.base.minX,
                    y: answered.minY + ask.target.minY - ask.base.minY,
                    width: ask.target.width,
                    height: ask.target.height
                ),
                animated: false,
                sizeLedFrom: SizeLedRun(
                    anchor: answered,
                    pressed: keys.isFiring
                )
            )
        }
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
