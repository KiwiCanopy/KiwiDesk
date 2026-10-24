import CoreGraphics
import Foundation

/// A Fill with no colour (#2569 ▸ "No Colour"): an empty,
/// unparseable or fully transparent hex is one state. `GlassTint`,
/// the solid paths (`NSColor(kiwiFill:)`) and Settings read it here.
extension KiwiShelf {
    /// Whether `hex` is a colour at all: parseable, above zero alpha.
    public static func hasColour(_ hex: String) -> Bool {
        (DragVisual.parseHex(hex)?.alpha ?? 0) > 0
    }

    /// Whether the Fill has a colour.
    public var hasFill: Bool { Self.hasColour(fillColor) }

    /// `hex` with no colour, its hue kept so raising the opacity
    /// brings it back: Settings' "No Color".
    public static func cleared(_ hex: String) -> String {
        guard let rgba = DragVisual.parseHex(hex) else { return "#00000000" }
        let bytes = [rgba.red, rgba.green, rgba.blue].map {
            String(format: "%02X", Int(($0 * 255).rounded()))
        }
        return "#" + bytes.joined() + "00"
    }
}
