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
