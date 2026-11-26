import SwiftUI

/// Reduce Motion's exit from the look picker (#3038 ▸ Ruling
/// 2026-11-23): a 0.2 s cross-fade in place of the puddle, a fade
/// with no travel that plays only for a Reduce Motion user — the
/// gate is named in the argument, inverted.
@MainActor
enum LookPickerCrossFade {
    static func play(_ reveal: LookPickerReveal, reduceMotion: Bool) {
        withAnimation(
            reduceMotion
                ? .easeInOut(duration: LookPickerReveal.crossFade) : nil
        ) {
            reveal.opacity = 0
        }
    }
}
