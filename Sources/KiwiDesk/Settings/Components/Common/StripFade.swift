import KiwiDeskCore
import SwiftUI

/// A sideways strip's mask: opaque, fading out over each end's
/// length (`ShelfOverflow.fades`). Instant, never animated, like the
/// bars' (`ShelfFadeMask`). A mask reads only alpha, so any opaque
/// token serves as its ink.
struct StripFade: View {
    let fades: ShelfOverflow.Fades

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, SettingsTheme.ink],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fades.leading)
            Rectangle().fill(SettingsTheme.ink)
            LinearGradient(
                colors: [SettingsTheme.ink, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: fades.trailing)
        }
    }
}
