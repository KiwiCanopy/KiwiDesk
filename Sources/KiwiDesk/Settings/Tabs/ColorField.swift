import KiwiDeskCore
import SwiftUI

/// A labeled color control (#68 §3.14): a native color well
/// (opens the system color panel) as the primary affordance,
/// with the `#RRGGBB` / `#RRGGBBAA` hex string kept beside it
/// as the copy/paste-friendly secondary — theme sharing via
/// hex strings is a real workflow and stays first-class. One
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
            TextField("#RRGGBBAA", text: $hex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .frame(maxWidth: 110)
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
