import AppKit

/// The expand/collapse glide of the Space run (#1683): when the
/// Space a screen shows changes under a collapsing content, the
/// run re-sizes, and its items travel there through `BarMotion`.
extension SpaceBarOverlay {
    /// Whether a render's items glide to their frames: only where
    /// the same items are drawn and the Space the screen shows
    /// changed under a content that collapses the others. Every
    /// other render lands — among them a `hide_empty` change,
    /// where pooled views would slide between different Spaces'
    /// slots. The shelf plate and section divider take the
    /// shelf's own glide; the front-app segment lands.
    nonisolated static func itemsGlide(
        content: SpaceBarStyle.InactiveContent,
        from shown: SpaceID?,
        to expanded: SpaceID?,
        sameItems: Bool
    ) -> Bool {
        content != .apps && sameItems && shown != nil
            && shown != expanded
    }

    /// Decides this render's glide and records what it drew, so
    /// the next render is told a switch from a steady pass.
    func recordGlide(
        _ items: [Item],
        content: SpaceBarStyle.InactiveContent
    ) -> Bool {
        let expanded = activeIndex(items).flatMap { items[$0].space }
        let identities = items.map(\.identity)
        let glides = Self.itemsGlide(
            content: content,
            from: shownExpanded,
            to: expanded,
            sameItems: identities == shownIdentities
        )
        shownExpanded = expanded
        shownIdentities = identities
        return glides
    }

    /// Places the items the container hosts; an item a glass box
    /// hosts rides its glass, which `updateBoxGlasses` moves.
    func placeItems(_ frames: [CGRect], glides: Bool) {
        BarMotion.runLayout {
            for (index, view) in itemViews.enumerated()
            where index < frames.count
                && view.superview === itemRun
            {
                moveFrame(view, frames[index], glides)
            }
        }
    }
}
