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
        /// Windows hidden past the glyph cap ("+n" badge).
        let overflow: Int
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }

    private var panel: NSPanel?
    var itemViews: [SpaceBarItemView] = []
    // The optional trailing front-app segment (#293 verdict 6):
    // a divider rule, the focused app's glyph, and — on
    // horizontal bars only — its name.
    let frontDivider = NSView()
    let frontIcon = NSImageView()
    let frontGlyph: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let frontName = NSTextField(labelWithString: "")
    private var lastShown:
        (
            items: [Item],
            frontApp: SpaceBarItemView.App?,
            strip: CGRect,
            style: SpaceBarStyle
        )?

    public init() {}

    public var isVisible: Bool { panel?.isVisible ?? false }

    /// The panel's content view, for the front-segment
    /// extension (the panel itself stays private).
    var panelContentView: NSView? { panel?.contentView }

    /// Renders `items` into `strip` (AX coordinates).
    /// `frontApp` is the trailing segment's app; nil while the
    /// toggle is off or no window is focused.
    func show(
        items: [Item],
        frontApp: SpaceBarItemView.App? = nil,
        strip: CGRect,
        style: SpaceBarStyle
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        lastShown = (items, frontApp, strip, style)
        render()
    }

    public func hide() {
        lastShown = nil
        panel?.orderOut(nil)
    }

    // MARK: - Rendering

    private func render() {
        guard let state = lastShown else { return }
        let (items, frontApp, strip, style) = state
        let panel = self.panel ?? makePanel()
        self.panel = panel
        styleContainer(panel, style: style, strip: strip)
        syncItemViewCount(items.count)
        let horizontal = style.edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let lengths = items.map { item in
            style.boxSize > 0
                ? style.boxSize
                : SpaceBarItemView.autoLength(
                    appCount: item.apps.count,
                    overflow: item.overflow,
                    depth: depth
                )
        }
        // Items plus the trailing front segment align as ONE
        // run — an end-aligned bar must end at the strip's
        // rim including the segment, not push it past.
        let total =
            lengths.reduce(0, +)
            + style.boxGap
            * CGFloat(max(items.count - 1, 0))
            + frontExtent(
                frontApp,
                depth: depth,
                horizontal: horizontal,
                style: style
            )
        var cursor = Self.contentStart(
            total: total,
            axis: horizontal ? strip.width : strip.height,
            alignment: style.alignment,
            pad: SpaceBarItemView.pad
        )
        for (index, item) in items.enumerated() {
            let view = itemViews[index]
            let length = lengths[index]
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
            cursor += length + style.boxGap
            view.configure(
                space: item.space,
                spaceGlyph: item.spaceGlyph,
                apps: item.apps,
                active: item.active,
                horizontal: horizontal,
                style: style,
                overflow: item.overflow
            )
            view.onSelect = { [weak self] space in
                self?.onSelect(space)
            }
        }
        renderFrontSegment(
            frontApp,
            after: cursor,
            strip: strip,
            style: style,
            horizontal: horizontal
        )
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

    /// Axis start of the content run per `alignment` (#293
    /// QA). `pad` keeps the run off the strip's rim and floors
    /// every case — a run larger than the axis falls back to
    /// start (the space count is bounded, no scroll here).
    /// `pad` is a parameter (callers pass
    /// `SpaceBarItemView.pad`) so this stays nonisolated and
    /// unit-testable.
    nonisolated static func contentStart(
        total: CGFloat,
        axis: CGFloat,
        alignment: SpaceBarStyle.Alignment,
        pad: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .start: return pad
        case .center: return max((axis - total) / 2, pad)
        case .end: return max(axis - total - pad, pad)
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
