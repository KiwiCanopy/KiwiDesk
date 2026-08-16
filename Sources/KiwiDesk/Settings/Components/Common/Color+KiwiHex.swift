import KiwiDeskCore
import SwiftUI

extension Color {
    /// SwiftUI twin of the runtime bar's `NSColor(kiwiHex:)`,
    /// for the settings previews (#125): both parse a user hex
    /// string through the same `DragVisual.parseHex`, so a
    /// *valid* preview color always matches the rendered one.
    /// The failure paths differ on purpose — this falls back to
    /// clear (an invalid color reads as "nothing" in a preview),
    /// while the runtime bar substitutes the accent color; only
    /// a hand-broken hex reaches either.
    /// A colour whose EMPTY value means "Automatic" rather than
    /// "unset" — the two mark tints (#429), which
    /// `ColorPaletteKeys.allowsAutomatic` identifies by their
    /// bare `.color` key.
    ///
    /// `Color(kiwiHex:)` maps an unparseable hex to `.clear`,
    /// which is right for an invalid colour and wrong for this
    /// one: Automatic is the adaptive label colour that flips
    /// with light and dark, so falling through to clear draws a
    /// mark that IS configured as an empty hole in the preview.
    /// A palette scene shipped exactly that for the sticky and
    /// floating marks at their shipped defaults (#793 review),
    /// which is a preview claiming the app draws nothing where
    /// it draws a mark.
    static func kiwiMark(_ hex: String) -> Color {
        hex.isEmpty ? .primary : Color(kiwiHex: hex)
    }

    init(kiwiHex hex: String) {
        guard let c = DragVisual.parseHex(hex) else {
            self = .clear
            return
        }
        self.init(
            red: c.red,
            green: c.green,
            blue: c.blue,
            opacity: c.alpha
        )
    }
}
