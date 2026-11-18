import KiwiDeskCore
import SwiftUI

/// The secondary line under a minimum window size that says what
/// it fits on the main screen (#3461). Core counts; this names
/// the screen and the counts, and draws nothing with no screen.
struct MinSizeFitLine: View {
    let fit: MinSizeFit?

    var body: some View {
        if let fit {
            Text(Self.sentence(for: fit))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The readout for `fit`: each count behind its label, so no
    /// word agrees with a number (#796), or that a window there
    /// cannot reach the size on either axis.
    static func sentence(for fit: MinSizeFit) -> String {
        guard fit.across > 0, fit.down > 0 else {
            return L(
                "layout_defaults.min_size.fits_none",
                "Doesn't fit on %1$@: a window there can't reach this "
                    + "size.",
                fit.screen.displayName
            )
        }
        return L(
            "layout_defaults.min_size.fits",
            "Fits on %1$@ — Across: %2$d · Down: %3$d",
            fit.screen.displayName,
            fit.across,
            fit.down
        )
    }
}
