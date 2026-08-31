import KiwiDeskCore
import SwiftUI

extension Color {
    /// Resolves mark tint from hex, or `.primary` for the empty
    /// "Automatic" sentinel (#429): `Color(kiwiHex:)` maps empty to
    /// `.clear`, which would preview a configured mark as a hole
    /// (#793).
    static func kiwiMark(_ hex: String) -> Color {
        hex.isEmpty ? .primary : Color(kiwiHex: hex)
    }

    /// Initializes SwiftUI Color from Kiwi hex string
    /// (`DragVisual.parseHex`, #125).
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
