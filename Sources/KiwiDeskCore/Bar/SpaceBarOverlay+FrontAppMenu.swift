import AppKit

/// The front-app segment's right-click (#2024): the focused
/// window's rows, shaped like an App Bar item's, under the app's
/// header. The segment is plain labels over a box, so the section
/// root asks here by point rather than a view answering itself.
extension SpaceBarOverlay {
    /// The segment's hit, or the shelf section's where no front
    /// app is shown.
    var frontMenuHit: BarHit {
        frontWindows.isEmpty ? .empty : .appItem(frontWindows)
    }

    /// The segment's hit for `point` in the root's coordinates, or
    /// nil outside it.
    func frontHit(at point: NSPoint) -> BarHit? {
        guard !frontWindows.isEmpty else { return nil }
        // Whatever draws the chip — box, glass or indicator — and
        // its content; a part the run clips out is not drawn.
        let drawn: [NSView?] = [
            frontBox, frontGlass, frontAccentClip, frontIcon,
            frontGlyph, frontName,
        ]
        let shown = drawn.compactMap { $0 }
            .filter { !$0.isHidden }
            .compactMap { view in
                view.superview.map { root.convert(view.frame, from: $0) }
            }
        let clipped =
            frontIcon.isDescendant(of: itemContainer)
            || frontName.isDescendant(of: itemContainer)
        guard
            let segment = Self.chipArea(
                shown,
                clip: clipped ? itemContainer.frame : nil
            )
        else { return nil }
        return segment.contains(point) ? frontMenuHit : nil
    }

    /// The area `drawn` covers, cut to `clip` where a container
    /// clips it; nil where nothing is drawn.
    static func chipArea(_ drawn: [CGRect], clip: CGRect?) -> CGRect? {
        guard let first = drawn.first else { return nil }
        let union = drawn.dropFirst().reduce(first) { $0.union($1) }
        return clip.map { union.intersection($0) } ?? union
    }
}

/// The front chip's icon and text glyph, answering VoiceOver per
/// query so the rows stay as current as the right-click's (#2024).
final class FrontChipIcon: NSImageView {
    var actions: () -> [NSAccessibilityCustomAction] = { [] }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        actions()
    }
}

final class FrontChipGlyph: NSTextField {
    var actions: () -> [NSAccessibilityCustomAction] = { [] }

    override func accessibilityCustomActions()
        -> [NSAccessibilityCustomAction]?
    {
        actions()
    }
}
