import AppKit
import KiwiDeskCore

extension ColorSwatch {
    /// Whether a well holds no colour: only a `clearable` one can
    /// (#2569).
    static func isClear(_ hex: String, clearable: Bool) -> Bool {
        clearable && !KiwiShelf.hasColour(hex)
    }

    /// What the field shows for `hex`: empty while the well holds no
    /// colour, so its placeholder reads "No Color" (#2691). A well
    /// that is also `automatic` keeps the hex, its empty field being
    /// Automatic's.
    static func shown(
        _ hex: String,
        automatic: Bool,
        clearable: Bool
    ) -> String {
        !automatic && isClear(hex, clearable: clearable) ? "" : hex
    }

    /// What a commit of `draft` writes over `current`, or nil when
    /// it writes nothing: an unparseable draft, or one naming the
    /// colour already stored — a blur is not an edit, and a well
    /// whose binding writes several rows (#1857) must not repaint
    /// them on one. An empty draft commits Automatic, else on a
    /// `clearable` well No Color with the hue kept (#2691).
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
