import AppKit

/// The front-app segment's fixed length (#2086, owner ruling): its
/// name draws in the bars' one `BarTitleSlot`, so a focus change
/// moves no frame.
extension SpaceBarOverlay {
    /// The slot `style` draws its front name in at `depth`.
    static func titleSlot(_ style: SpaceBarLook, depth: CGFloat) -> CGFloat {
        BarTitleSlot.length(
            cap: style.bar.resolvedFrontAppTitleCap,
            font: style.shelf.textFont(
                ofSize: style.titleFontSize(forDepth: depth)
            )
        )
    }
}
