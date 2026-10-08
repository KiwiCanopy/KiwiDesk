import AppKit

/// The expand/collapse glide of the Space run (#1683): when the
/// Space a screen shows changes under a collapsing content, the
/// run re-sizes, and its items travel there through `BarMotion`.
extension SpaceBarOverlay {
    /// Whether a render's items glide to their frames: only where
    /// the same items are drawn in the same slot and the Space the
    /// screen shows changed under a content that collapses the
    /// others. Every other render lands — among them a `hide_empty`
    /// change, where pooled views would slide between different
    /// Spaces' slots, and a slot that moved or resized, where the
    /// shelf glides the whole section from where its content was
    /// drawn and a run gliding inside it would pull that content
    /// away from the start (#1838). The shelf plate and section
    /// divider take the shelf's own glide. A front-app segment
    /// joining or leaving the same items in the same slot re-places
    /// the run, which glides beside its grow or shrink (#1903).
    nonisolated static func itemsGlide(
        content: SpaceBarStyle.InactiveContent,
        from shown: SpaceID?,
        to expanded: SpaceID?,
        sameItems: Bool,
        sameSlot: Bool,
        frontMoves: Bool = false
    ) -> Bool {
        guard sameItems, sameSlot else { return false }
        return frontMoves
            || (content != .apps && shown != nil && shown != expanded)
    }

    /// Decides this render's glide and records what it drew, so
    /// the next render is told a switch from a steady pass.
    func recordGlide(
        _ items: [Item],
        content: SpaceBarStyle.InactiveContent,
        slotChanged: Bool,
        frontMoves: Bool
    ) -> Bool {
        let expanded = activeIndex(items).flatMap { items[$0].space }
        let identities = items.map(\.identity)
        let glides = Self.itemsGlide(
            content: content,
            from: shownExpanded,
            to: expanded,
            sameItems: identities == shownIdentities,
            sameSlot: !slotChanged,
            frontMoves: frontMoves
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
