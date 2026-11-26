import SwiftUI

/// Reduce Motion's exit from the look picker (#3038 ▸ Ruling
/// 2026-11-23): a 0.2 s cross-fade, played ONLY for a Reduce Motion
/// user in place of the puddle. A fade with no travel, by ruling —
/// `ReduceMotionGateTests`' `allowed` map names this file.
@MainActor
enum LookPickerCrossFade {
    static func play(_ reveal: LookPickerReveal) {
        withAnimation(.easeInOut(duration: LookPickerReveal.crossFade)) {
            reveal.opacity = 0
        }
    }
}
