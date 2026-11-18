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

    /// The readout for `fit`: the counts, or that a window there
    /// cannot reach the size on either axis.
    static func sentence(for fit: MinSizeFit) -> String {
        guard fit.across > 0, fit.down > 0 else {
            return L(
                "layout_defaults.min_size.fits_none",
                "Larger than %1$@, so a window there can't reach "
                    + "this size.",
                fit.screen
            )
        }
        return L(
            "layout_defaults.min_size.fits",
            "On %1$@, this fits %2$d across and %3$d down.",
            fit.screen,
            fit.across,
            fit.down
        )
    }
}
