import KiwiDeskCore
import SwiftUI

/// A labeled color control (#68 §3.14): just the native color
/// well — the system color panel it opens carries hex entry
/// natively (Color Sliders pane), so the inline `#RRGGBBAA`
/// text field it used to pair with was redundant chrome and
/// was dropped. The stored value stays a hex string. One
/// component everywhere a color appears (App Bar, overrides,
/// drag visuals).
struct HexColorField: View {
    let label: String
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 140, alignment: .leading)
            ColorPicker(
                "",
                selection: colorBinding,
                supportsOpacity: true
            )
            .labelsHidden()
        }
    }

    /// The well edits the same stored hex string: reads via
    /// `DragVisual.parseHex`, writes back `#RRGGBB` (or
    /// `#RRGGBBAA` when translucent).
    private var colorBinding: Binding<Color> {
        Binding(
            get: { parsedColor },
            set: { hex = Self.hexString(from: $0) }
        )
    }

    /// Parses `hex` via `DragVisual.parseHex` (handles
    /// `#RRGGBB` and `#RRGGBBAA`). Falls back to `.clear`.
    private var parsedColor: Color {
        guard let rgba = DragVisual.parseHex(hex) else {
            return .clear
        }
        return Color(
            red: rgba.red,
            green: rgba.green,
            blue: rgba.blue,
            opacity: rgba.alpha
        )
    }

    static func hexString(from color: Color) -> String {
        let ns =
            NSColor(color).usingColorSpace(.sRGB)
            ?? .black
        let r = Int(round(ns.redComponent * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent * 255))
        let a = Int(round(ns.alphaComponent * 255))
        if a >= 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return String(
            format: "#%02X%02X%02X%02X",
            r,
            g,
            b,
            a
        )
    }
}
