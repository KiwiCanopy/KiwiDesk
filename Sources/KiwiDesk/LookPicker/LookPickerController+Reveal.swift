import AppKit
import KiwiDeskCore
import SwiftUI

/// The wear and the puddle reveal (#3038 ▸ Ruling 2026-11-23, steps
/// 1–4): Core wears the look under the opaque overlay, the reveal
/// waits for the desk at most `readyCap`, then the drop, the blur and
/// the wave; Reduce Motion takes the cross-fade instead.
extension LookPickerController {
    /// ↩ on a look not worn: Core wears it with the windows placed at
    /// once, then the reveal waits for the desk — at most
    /// `readyCap` — whichever comes first.
    func wear(_ entry: LookPickerEntry) {
        let current = opening
        let latch = ResumeLatch()
        let resume: @MainActor () -> Void = { [weak self] in
            guard !latch.fired, let self, opening == current else { return }
            latch.fired = true
            startReveal()
        }
        announce(LookPickerText.wearing(entry.look.name))
        core.wearPickedLook(entry.look, ready: resume)
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
            LookPickerCrossFade.play(reveal)
            after(LookPickerReveal.crossFade, finish)
            return
        }
        reveal.dropShown = true
        withAnimation(
            reduceMotion ? nil : .easeIn(duration: LookPickerReveal.fall)
        ) {
            reveal.dropLanded = true
        }
        let reach = Self.reach(of: geometry)
        after(LookPickerReveal.fall) { [weak self] in
            guard self?.opening == current else { return }
            withAnimation(
                reduceMotion
                    ? nil : .easeOut(duration: LookPickerReveal.splash)
            ) {
                reveal.dropSplashed = true
            }
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
        let centre = CGPoint(x: geometry.card.midX, y: geometry.card.midY)
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
