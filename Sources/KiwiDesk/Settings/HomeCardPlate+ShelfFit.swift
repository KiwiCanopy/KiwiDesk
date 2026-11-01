import CoreGraphics
import KiwiDeskCore

extension ShelfStripPreview {
    /// This strip with its App Bar's mock items cut from the end,
    /// down to one, until the rest fit their slot whole: a
    /// thumbnail drops what it has no room for by not drawing it
    /// (gui.md, #2781). The Space Bar's items are the user's own
    /// Spaces and are never cut.
    func fitted(length: CGFloat) -> ShelfStripPreview {
        var strip = self
        while var spec = strip.app, spec.items.count > 1,
            let slot = strip.arrangement(length: length).app,
            strip.overflows(spec, slot)
        {
            spec.items.removeLast()
            strip.app = spec
        }
        return strip
    }
}
