import AppKit

/// A shelf section's root view (#1517): flipped like every bar
/// view, and the one place a wheel or trackpad reaches a section.
/// A scroll bubbles here from whichever item is under the pointer;
/// `onScroll` answers whether the section took it, and one it
/// declines — nothing hidden — goes up the responder chain.
@MainActor
final class ShelfSectionRoot: AppBarOverlay.FlippedView {
    var onScroll: (ShelfScrollInput.Delta) -> Bool = { _ in false }

    override func scrollWheel(with event: NSEvent) {
        let delta = ShelfScrollInput.Delta(
            x: event.scrollingDeltaX,
            y: event.scrollingDeltaY,
            precise: event.hasPreciseScrollingDeltas
        )
        if !onScroll(delta) { super.scrollWheel(with: event) }
    }
}
