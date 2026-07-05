import KiwiDeskCore
import SwiftUI

/// A labeled row: a monospaced hex text field and a live
/// color swatch that reflects the parsed RGBA value.
///
/// Reads and writes `#RRGGBB` / `#RRGGBBAA` strings as
/// used by `AppBarStyle` and `DragVisual`.
struct HexColorField: View {
    let label: String
    @Binding var hex: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 140, alignment: .leading)
            TextField("#RRGGBBAA", text: $hex)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: 120)
            swatch
        }
    }

    private var swatch: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(parsedColor)
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(
                        Color.secondary.opacity(0.4),
                        lineWidth: 1
                    )
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
}
