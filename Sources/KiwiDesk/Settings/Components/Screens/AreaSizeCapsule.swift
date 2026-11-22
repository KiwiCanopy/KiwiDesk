import Foundation
import KiwiDeskCore
import SwiftUI

/// An area's length while a divider beside it moves (#3517 ruling
/// 25): "1147 pt", with the screen fraction a snap landed it on,
/// "1147 pt · ⅓".
struct AreaSizeCapsule: View {
    let length: Int
    let snap: ScreenAreaSnap?
    /// The screen's length along the divider's axis.
    let total: Int

    var body: some View {
        Text(Self.label(length: length, snap: snap, total: total))
            .font(.caption.monospacedDigit())
            .foregroundStyle(SettingsTheme.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Capsule().fill(SettingsTheme.chipRest))
            .overlay(Capsule().strokeBorder(SettingsTheme.chipEdge))
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The fraction is named on the area whose length is that share
    /// of the screen; the even point's cue is the two equal numbers.
    static func label(
        length: Int,
        snap: ScreenAreaSnap?,
        total: Int
    ) -> String {
        if case .fraction(let n, let d)? = snap,
            length == (total * n + d / 2) / d,
            let glyph = glyphs[[n, d]]
        {
            return L(
                "monitor_card.divider.size_fraction",
                "%1$d pt · %2$@",
                length,
                glyph
            )
        }
        return L("monitor_card.divider.size", "%1$d pt", length)
    }

    private static let glyphs: [[Int]: String] = [
        [1, 4]: "¼", [1, 3]: "⅓", [1, 2]: "½", [2, 3]: "⅔", [3, 4]: "¾",
    ]
}
