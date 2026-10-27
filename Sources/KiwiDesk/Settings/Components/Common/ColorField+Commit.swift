import AppKit
import KiwiDeskCore

extension ColorSwatch {
    /// What the field shows for `hex`: empty while a clearable well
    /// holds no colour, so its placeholder reads "No Color" (#2569).
    static func shown(_ hex: String, clearable: Bool) -> String {
        clearable && !KiwiShelf.hasColour(hex) ? "" : hex
    }

    /// What a commit of `draft` writes over `current`, or nil when
    /// it writes nothing: an unparseable draft, or one naming the
    /// colour already stored — a blur is not an edit, and a well
    /// whose binding writes several rows (#1857) must not repaint
    /// them on one. An empty draft commits Automatic, else on a
    /// `clearable` well No Color with the hue kept (#2569).
    static func committed(
        draft: String,
        over current: String,
        automatic: Bool,
        clearable: Bool = false
    ) -> String? {
        let empty = draft.trimmingCharacters(in: .whitespaces).isEmpty
        if automatic, empty {
            return current.isEmpty ? nil : ""
        }
        if clearable, empty {
            return KiwiShelf.hasColour(current)
                ? KiwiShelf.cleared(current) : nil
        }
        guard let rgba = DragVisual.parseHex(draft),
            rgba != DragVisual.parseHex(current)
        else { return nil }
        let ns = NSColor(
            srgbRed: CGFloat(rgba.red),
            green: CGFloat(rgba.green),
            blue: CGFloat(rgba.blue),
            alpha: CGFloat(rgba.alpha)
        )
        return HexColorField.hexString(from: ns)
    }
}
