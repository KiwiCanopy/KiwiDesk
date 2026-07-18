import AppKit

/// The Space Bar panel for one display (#293): renders Space
/// items into a strip handed to it in AX coordinates. A dumb
/// renderer like `AppBarOverlay` — the driver resolves state,
/// identifiers, and glyphs. Items size to their content
/// (identifier + app glyphs), so lengths vary per item; items
/// that overflow the strip clip at its end (spaces are a small,
/// bounded set — no scroll machinery in v1).
@MainActor
public final class SpaceBarOverlay {
    /// One Space's resolved content.
    public struct Item {
        let space: SpaceID
        let spaceGlyph: SpaceBarItemView.Identifier
        let apps: [SpaceBarItemView.App]
        let active: Bool
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    private var panel: NSPanel?
    var itemViews: [SpaceBarItemView] = []
    private var lastShown:
        (
            items: [Item], strip: CGRect, style: SpaceBarStyle
        )?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// Renders `items` into `strip` (AX coordinates).
    public func show(
        items: [Item],
        strip: CGRect,
        style: SpaceBarStyle
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        lastShown = (items, strip, style)
        render()
    }

    public func hide() {
        lastShown = nil
        panel?.orderOut(nil)
    }

    // MARK: - Rendering

    private func render() {
        guard let state = lastShown else { return }
        let (items, strip, style) = state
        let panel = self.panel ?? makePanel()
        self.panel = panel
        styleContainer(panel, style: style, strip: strip)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        var cursor: CGFloat = SpaceBarItemView.pad
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            let length =
                style.itemSize > 0
                ? style.itemSize
                : SpaceBarItemView.autoLength(
                    appCount: item.apps.count,
                    depth: depth
                )
            view.frame =
                horizontal
                ? CGRect(
                    x: cursor,
                    y: 0,
                    width: length,
                    height: strip.height
                )
                : CGRect(
                    x: 0,
                    y: cursor,
                    width: strip.width,
                    height: length
                )
            cursor += length + style.itemGap
            view.configure(
                space: item.space,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
        }
        panel.setFrame(
            GeometryUtils.flip(
                strip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func styleContainer(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        let depth =
            style.edge.isHorizontal
            ? strip.height : strip.width
        layer.masksToBounds = true
        layer.cornerRadius =
            style.tabBackground == .plain
            ? style.resolvedCornerRadius(forThickness: depth)
            : 0
        let background =
            style.tabBackground == .plain
            ? style.boxColor
            : style.backgroundColor
        layer.backgroundColor =
            NSColor(kiwiHex: background).cgColor
    }

    private func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = SpaceBarItemView()
            itemViews.append(view)
            panel?.contentView?.addSubview(view)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        let view = AppBarOverlay.FlippedView()
        view.wantsLayer = true
        panel.contentView = view
        return panel
    }
}
