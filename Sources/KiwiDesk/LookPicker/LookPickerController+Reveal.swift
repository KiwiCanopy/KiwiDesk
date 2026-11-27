import AppKit
import KiwiDeskCore
import QuartzCore
import SwiftUI

/// The wear and the puddle reveal (#3038 ▸ Ruling 2026-11-23, steps
/// 1–4): Core wears the look under the opaque overlay, the reveal
/// waits for the desk at most `readyCap`, then the drop lands and
/// sinks, and only then the blur and the wave (amended 2026-11-26);
/// Reduce Motion takes the cross-fade instead.
extension LookPickerController {
    /// ↩ on a look not worn: Core wears it with the windows placed at
    /// once, then the reveal waits for the desk — at most
    /// `readyCap` — whichever comes first. The fall starts after the
    /// commit of the transaction the wear's call ran in, not inside
    /// it (#3700); the frame log measures what that buys.
    func wear(_ entry: LookPickerEntry) {
        let current = opening
        let latch = ResumeLatch()
        let resume: @MainActor () -> Void = { [weak self] in
            guard !latch.fired, let self, opening == current else { return }
            latch.fired = true
            afterCommit { [weak self] in
                guard let self, opening == current else { return }
                startReveal()
            }
        }
        announce(LookPickerText.wearing(entry.look.name))
        let log = LookPickerFrameLog()
        log.start(on: panel?.screen)
        _ = frameLog?.stop()
        frameLog = log
        let start = CACurrentMediaTime()
        core.wearPickedLook(entry.look, ready: resume)
        log.wear = CACurrentMediaTime() - start
        after(Self.readyCap, resume)
    }

    private func startReveal() {
        guard panel != nil else { return }
        revealing = true
        let reveal = self.reveal
        let current = opening
        let reduceMotion = reduceMotionNow
        let finish: @MainActor () -> Void = { [weak self] in
            guard let self, opening == current else { return }
            close()
        }
        if reduceMotion {
            LookPickerCrossFade.play(reveal, reduceMotion: reduceMotion)
            after(LookPickerReveal.crossFade, finish)
            return
        }
        let drop = dropView
        drop?.prepare(landingAt: geometry.landing)
        drop?.fall(reduceMotion: reduceMotion)
        after(LookPickerReveal.fall) { [weak self] in
            guard self?.opening == current else { return }
            drop?.squash(reduceMotion: reduceMotion)
        }
        let sinkAt = LookPickerReveal.fall + LookPickerReveal.squashHold
        after(sinkAt) { [weak self] in
            guard self?.opening == current else { return }
            drop?.sink(reduceMotion: reduceMotion)
        }
        let reach = Self.reach(of: geometry)
        after(sinkAt + LookPickerReveal.waveLead) { [weak self] in
            guard self?.opening == current else { return }
            withAnimation(
                reduceMotion
                    ? nil : .easeOut(duration: LookPickerReveal.blurIn)
            ) {
                reveal.blur = LookPickerReveal.blurRadius
            }
            reveal.waveShown = true
            withAnimation(
                reduceMotion ? nil : .easeOut(duration: LookPickerReveal.wave)
            ) {
                reveal.holeRadius = reach
            }
            self?.after(LookPickerReveal.wave, finish)
        }
    }

    /// How far the wave travels: past the corner farthest from the
    /// card's centre, its band included.
    static func reach(of geometry: LookPickerGeometry) -> CGFloat {
        let size = geometry.screen
        let centre = geometry.landing
        let corners = [
            CGPoint.zero, CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        let far =
            corners.map { hypot($0.x - centre.x, $0.y - centre.y) }
            .max() ?? 0
        return far + LookPickerReveal.band
    }

}

/// Resumes the reveal once: Core's `ready` or the cap, first wins.
@MainActor
private final class ResumeLatch {
    var fired = false
}
