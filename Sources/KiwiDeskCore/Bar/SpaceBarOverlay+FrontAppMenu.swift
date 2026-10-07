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
        // The box where the style draws one, else the content.
        let shown = [frontBox, frontIcon, frontGlyph, frontName]
            .filter { !$0.isHidden }
            .compactMap { view in
                view.superview.map { root.convert(view.frame, from: $0) }
            }
        guard let first = shown.first else { return nil }
        let segment = shown.dropFirst().reduce(first) { $0.union($1) }
        return segment.contains(point) ? frontMenuHit : nil
    }
}
