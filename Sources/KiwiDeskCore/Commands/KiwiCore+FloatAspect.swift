import CoreGraphics
import Foundation

/// A float whose app holds its aspect ratio, judged from its answers
/// (#2973). AX states no such lock, but a locked app fits a size ask
/// inside the asked box: a one-axis grow lands nowhere and a one-axis
/// shrink moves both axes. `docs/design-decisions.md` has the argument.
extension KiwiCore {
    /// One press being judged.
    struct FloatAspectAsk {
        let window: WindowID
        let axis: String
        let delta: Double
        let base: CGRect
        let asked: CGSize
    }

    /// The small one-axis shrink that proves a lock, in points. It
    /// must outlast `FloatResize.answerTolerance` on the other axis.
    static let floatAspectProbeStep: CGFloat = 12
    /// Wait for a probe's answer, in seconds.
    static let floatAspectProbeSeconds = 0.3

    /// Arms the judgement of a press on a float not judged yet.
    func oweFloatAspectJudgement(_ ask: FloatAspectAsk) {
        guard state.floatAspects[ask.window] == nil,
            ask.asked != ask.base.size
        else { return }
        deferred.schedule(
            .floatAspect,
            after: .seconds(Self.sizeBoundProbeGraceSeconds)
        ) { [weak self] in
            self?.judgeFloatAspect(ask)
        }
    }

    /// Reads the press's answer. A hold is waited out, since its own
    /// writes would overwrite the probe.
    func judgeFloatAspect(_ ask: FloatAspectAsk) {
        guard !keys.isGliding else {
            oweFloatAspectJudgement(ask)
            return
        }
        guard let pid = judgedFloatPid(ask.window),
            let live = windowServer.readWindowBounds(ask.window)
        else { return }
        switch FloatResize.aspectAnswer(
            base: ask.base.size,
            asked: ask.asked,
            answered: live.size
        ) {
        case .fitted:
            lockFloatAspect(ask.window, pid: pid, ratio: ask.base)
        case .complied:
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
        case .unchanged where ask.delta > 0:
            probeFloatAspect(ask, live: live)
        case .unchanged, .other:
            break
        }
    }

    /// A refused grow may be a lock or a fixed size: a shrink tells
    /// them apart, and a slow app's late grow cannot pass for it.
    private func probeFloatAspect(_ ask: FloatAspectAsk, live: CGRect) {
        var probe = live
        if ask.axis == "x" {
            probe.size.width -= Self.floatAspectProbeStep
        } else {
            probe.size.height -= Self.floatAspectProbeStep
        }
        tiler.applyFrame(ask.window, from: live, to: probe, animated: false)
        deferred.schedule(
            .floatAspect,
            after: .seconds(Self.floatAspectProbeSeconds)
        ) { [weak self] in
            self?.judgeFloatAspectProbe(ask, live: live, probe: probe)
        }
    }

    /// Reads the probe's answer: a lock takes the press's step in
    /// proportion, from where the probe left it; anything else is
    /// free of a lock and goes back where it stood.
    func judgeFloatAspectProbe(
        _ ask: FloatAspectAsk,
        live: CGRect,
        probe: CGRect
    ) {
        guard let pid = judgedFloatPid(ask.window),
            let answered = windowServer.readWindowBounds(ask.window)
        else { return }
        let answer = FloatResize.aspectAnswer(
            base: live.size,
            asked: probe.size,
            answered: answered.size
        )
        guard answer == .fitted else {
            state.floatAspects[ask.window] = .init(pid: pid, ratio: nil)
            if answer != .unchanged {
                tiler.applyFrame(
                    ask.window,
                    from: answered,
                    to: live,
                    animated: false
                )
            }
            return
        }
        lockFloatAspect(ask.window, pid: pid, ratio: live)
        let lost =
            ask.axis == "x"
            ? live.width - answered.width
            : live.height - answered.height
        _ = resizeFloating(
            ask.window,
            axis: ask.axis,
            delta: ask.delta + lost
        )
    }

    /// The window still judged, as `resize` would still route it: a
    /// float of the active Space.
    private func judgedFloatPid(_ id: WindowID) -> pid_t? {
        guard let space = activeSpace,
            space.windows.contains(id),
            let window = state.windows[id],
            EffectiveFloat.applies(
                isFloating: window.isFloating,
                mode: space.mode
            )
        else { return nil }
        return window.pid
    }

    private func lockFloatAspect(
        _ id: WindowID,
        pid: pid_t,
        ratio frame: CGRect
    ) {
        guard frame.height > 0 else { return }
        state.floatAspects[id] = .init(
            pid: pid,
            ratio: frame.width / frame.height
        )
        onLog("window \(id.raw) holds its aspect ratio")
    }
}
