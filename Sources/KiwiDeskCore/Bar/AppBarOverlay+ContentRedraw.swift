import AppKit

/// A show that moves no frame redraws content alone (#2545, owner
/// ruling): every title draws in the one fixed `titleSlot`, so a
/// renamed window re-sets its item's text while the run, its
/// glass and the shelf around it stay where they are — the
/// front-app segment's rule (#2086).
extension AppBarOverlay {
    /// Whether `next` draws every frame `last` drew: the same slot,
    /// look, focus and Space, and items differing in their text
    /// alone.
    static func keepsGeometry(
        _ last: RenderState,
        _ next: RenderState
    ) -> Bool {
        last.strip == next.strip && last.style == next.style
            && last.capAxis == next.capAxis && last.space == next.space
            && last.activeIndex == next.activeIndex
            && last.items.count == next.items.count
            && zip(last.items, next.items).allSatisfy(samePlace)
    }

    /// Everything of an item but its words: a title present or
    /// absent places the icon, so only its spelling is content.
    private static func samePlace(_ old: Item, _ new: Item) -> Bool {
        old.id == new.id && old.count == new.count
            && old.members == new.members && old.floating == new.floating
            && old.visibility == new.visibility && old.icon == new.icon
            && old.glyph == new.glyph
            && old.text.isEmpty == new.text.isEmpty
    }

    /// Reconfigures the items whose content changed since `last`,
    /// then lets the shelf re-read its hover and peek.
    func redrawContent(since last: RenderState) {
        guard let state = lastShown, let style = drawnStyle,
            let horizontal = lastMetrics?.horizontal
        else { return }
        for (index, item) in state.items.enumerated()
        where index < itemViews.count && item != last.items[index] {
            configure(
                itemViews[index],
                item,
                at: index,
                of: state.items.count,
                active: index == state.activeIndex,
                horizontal: horizontal,
                style: style
            )
        }
        onRendered()
    }

    /// One item view's content and hooks — the render's and the
    /// redraw's.
    func configure(
        _ view: AppBarItemView,
        _ item: Item,
        at index: Int,
        of count: Int,
        active: Bool,
        horizontal: Bool,
        style: AppBarLook
    ) {
        view.isHidden = false
        view.configure(
            id: item.id,
            name: item.name,
            text: item.text,
            icon: item.icon,
            glyph: item.glyph,
            count: item.count,
            titleCut: item.titleCut,
            floating: item.floating,
            visibility: item.visibility,
            active: active,
            horizontal: horizontal,
            style: style
        )
        view.itemActions = itemActions
        view.members = item.members
        let place = Self.runPlace(index: index, count: count)
        view.isFirstInRun = place.first
        view.isLastInRun = place.last
        view.onSelect = { [weak self] id in
            self?.onSelect(id)
        }
        view.onDragMoved = { [weak self] view, point in
            self?.dragMoved(view, to: point)
        }
        view.onDragEnded = { [weak self] view in
            self?.dragEnded(view)
        }
    }
}
