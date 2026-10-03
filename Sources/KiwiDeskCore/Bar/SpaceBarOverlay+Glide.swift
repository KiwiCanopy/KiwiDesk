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
    /// divider take the shelf's own glide; the front-app segment
    /// lands.
    nonisolated static func itemsGlide(
        content: SpaceBarStyle.InactiveContent,
        from shown: SpaceID?,
        to expanded: SpaceID?,
        sameItems: Bool,
        sameSlot: Bool
    ) -> Bool {
        content != .apps && sameItems && sameSlot && shown != nil
            && shown != expanded
    }

    /// Decides this render's glide and records what it drew, so
    /// the next render is told a switch from a steady pass.
    func recordGlide(
        _ items: [Item],
        content: SpaceBarStyle.InactiveContent,
        slotChanged: Bool,
        horizontal: Bool = true
    ) -> Bool {
        let expanded = activeIndex(items).flatMap { items[$0].space }
        let identities = items.map(\.identity)
        let titles = items.map { $0.apps.map(\.inlineTitle) }
        let hasTitles = (titles + shownInlineTitles).joined().contains {
            $0 != nil
        }
        let titleChange =
            hasTitles
            && !shownInlineTitles.isEmpty
            && titles != shownInlineTitles
            && identities == shownIdentities
        let titleGlide = titleChange && !slotChanged
        resizesInlineTitles = titleChange && slotChanged && horizontal
        let glides =
            titleGlide
            || Self.itemsGlide(
                content: content,
                from: shownExpanded,
                to: expanded,
                sameItems: identities == shownIdentities,
                sameSlot: !slotChanged
            )
        shownInlineTitles = titles
        shownExpanded = expanded
        shownIdentities = identities
        return glides
    }

    /// Places the items the container hosts; an item a glass box
    /// hosts rides its glass, which `updateBoxGlasses` moves.
    func placeItems(_ frames: [CGRect], glides: Bool) {
        if resizesInlineTitles {
            BarMotion.standCommitted {
                for (index, view) in itemViews.enumerated()
                where index < frames.count && view.superview === itemRun {
                    standResize(view, at: frames[index])
                }
            }
        }
        let place = {
            for (index, view) in self.itemViews.enumerated()
            where index < frames.count
                && view.superview === self.itemRun
            {
                self.moveFrame(
                    view,
                    frames[index],
                    glides || self.resizesInlineTitles
                )
            }
        }
        if resizesInlineTitles {
            BarMotion.runPlateGlide(place)
        } else {
            BarMotion.runLayout(place)
        }
    }

    /// The shelf carries the content anchor; cells travel relative to it.
    func standResize(_ view: NSView, at frame: CGRect) {
        view.frame =
            view.frame == .zero
            ? frame
            : CGRect(
                x: view.frame.minX + inlineResizeShift,
                y: frame.minY,
                width: view.frame.width,
                height: view.frame.height
            )
    }
}
