import AppKit

/// One entry in the indicator bar: an optional app icon and
/// name centered in the slot, a style-dependent accent
/// marking the active window, a count badge on grouped
/// items, and click-to-focus. Clicks never take key focus —
/// the panel above is non-activating. Dragging past a small
/// threshold hands the item to the overlay's reorder logic
/// instead of clicking.
///
/// Slot layout & text measurement live in
/// AppBarItemView+Layout.swift.
final class AppBarItemView: NSView {
    let iconView = NSImageView()
    /// SketchyBar App Font ligature shown in the icon slot when
    /// the item carries a glyph (#294). Text, so it follows the
    /// bar's text colors; purely presentational to AX (the item
    /// announces the app name, never the ligature).
    let glyphLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let label = NSTextField(labelWithString: "")
    let accent = NSView()
    let badge: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        let cell = IndicatorBarBadgeCell(textCell: "")
        cell.alignment = .center
        cell.isEditable = false
        cell.isSelectable = false
        cell.isBordered = false
        cell.isBezeled = false
        cell.drawsBackground = false
        tf.cell = cell
        return tf
    }()

    private var windowID = WindowID(0)
    var name = ""
    var horizontal = true
    /// The concrete edge the bar sits on (from the resolved
    /// style); the active edge-mark hugs it.
    var edge: AppBarEdge { style.edge }
    private(set) var isActive = false
    private(set) var count = 1
    private var isHovered = false
    var style = AppBarStyle()
    var onSelect: (WindowID) -> Void = { _ in }
    var onDragMoved: (AppBarItemView, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (AppBarItemView) -> Void = { _ in }

    private var pressLocation: NSPoint?
    private var isDragging = false

    /// Only the focused window's own item is inert. A
    /// collapsed group is never active (focus inside a group
    /// expands it), so groups always take clicks.
    private var isInert: Bool { isActive && count == 1 }

    /// Flipped: content lays out top-down, so the icon sits
    /// at the visual top of vertical bars.
    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        accent.wantsLayer = true
        label.alignment = .center
        badge.wantsLayer = true
        badge.alignment = .center
        addSubview(iconView)
        addSubview(glyphLabel)
        addSubview(label)
        addSubview(accent)
        addSubview(badge)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppBarItemView is code-only")
    }

    // MARK: - Click, drag & hover

    /// Selection happens on mouse-up so a press can still
    /// become a drag; a drag right of the threshold never
    /// clicks.
    override func mouseDown(with event: NSEvent) {
        pressLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressLocation else { return }
        let location = event.locationInWindow
        if !isDragging,
            hypot(
                location.x - start.x,
                location.y - start.y
            ) > 4
        {
            isDragging = true
        }
        guard isDragging, let superview else { return }
        onDragMoved(
            self,
            superview.convert(location, from: nil)
        )
    }

    override func mouseUp(with event: NSEvent) {
        defer { pressLocation = nil }
        if isDragging {
            isDragging = false
            onDragEnded(self)
        } else if !isInert {
            onSelect(windowID)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .activeAlways,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        guard !isInert else { return }
        isHovered = true
        applyColors()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyColors()
    }

    // MARK: - Styling

    // swiftlint:disable:next function_parameter_count
    func configure(
        id: WindowID,
        name: String,
        icon: NSImage?,
        glyph: String?,
        count: Int,
        active: Bool,
        horizontal: Bool,
        style: AppBarStyle
    ) {
        windowID = id
        self.name = name
        self.count = count
        self.horizontal = horizontal
        self.isActive = active
        self.style = style
        isHovered = false
        iconView.image = icon
        let content = style.content.rendered(
            horizontal: horizontal
        )
        // Empty ligature (bad vendor drop) must not reserve a
        // blank square — treat it as no glyph.
        let showsGlyph =
            glyph?.isEmpty == false && content != .name
        glyphLabel.isHidden = !showsGlyph
        glyphLabel.stringValue = glyph ?? ""
        iconView.isHidden =
            showsGlyph || content == .name
            || icon == nil
        label.isHidden = content == .icon
        badge.isHidden = count < 2
        badge.stringValue = "\(count)"
        badge.textColor =
            NSColor(kiwiHex: style.groupBadgeTextColor)
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: style.groupBadgeColor).cgColor
        applyColors()
        applyAccent()
        needsLayout = true
    }

    /// Hover swaps the box background (no overlay: a wash on
    /// top would muddy the icon and text) and the text color.
    private func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        glyphLabel.textColor = NSColor(kiwiHex: textColorHex)
        // The app image never tints, so it carried no active
        // cue at all (QA 2026-07-19): half strength when
        // inactive, shape (accent) plus opacity carry the
        // state. Deliberately the full 0.5 dim, NOT the Space
        // Bar's 0.7 middle tier — this is a binary signal
        // reinforced by the ring, with no lower tier to
        // collide with (see `BarAccent.activeUnfocusedAlpha`).
        iconView.alphaValue =
            isActive || isHovered
            ? 1 : BarAccent.untintedAlpha
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        applyCornerRadius()
    }

    /// The tab's bar-cross dimension (its thickness), which the
    /// corner radius resolves against.
    var crossThickness: CGFloat {
        horizontal ? bounds.height : bounds.width
    }

    /// Round the box to `cornerRoundness`% of a capsule whenever
    /// a box is shown. Runs from both `layout()` (bounds known)
    /// and `applyColors()` (hover toggles the plain box).
    func applyCornerRadius() {
        layer?.cornerRadius =
            hasBox
            ? style.resolvedCornerRadius(
                forThickness: crossThickness
            )
            : 0
    }

    private var textColorHex: String {
        if isHovered { return style.hoverTextColor }
        return isActive
            ? style.activeTextColor
            : style.textColor
    }

    /// Whether this tab paints a box behind its content: always
    /// when `boxed`, and on hover (a `plain` tab reveals a box
    /// only while hovered). `plain` is otherwise boxless in every
    /// combo, including the active ring (which is a pure stroke).
    private var hasBox: Bool {
        if isHovered { return true }
        return style.tabBackground.rendered == .boxed
    }

    // The settings App Bar preview (`AppBarPreviewStrip`, GUI
    // target) is a schematic twin of this box/accent logic —
    // keep the two in step when the box or accent rules change.
    private var boxColorHex: String {
        if isHovered { return style.hoverColor }
        switch style.tabBackground.rendered {
        case .boxed:
            return isActive
                ? style.activeBoxColor
                : style.boxColor
        // `material` is boxless like `plain` — the glass plate is
        // the background, so items paint no box of their own.
        case .plain, .material:
            return "#00000000"
        }
    }

    /// How the active tab is marked, gated on the indicator and
    /// orthogonal to `tabBackground` (the background no longer
    /// secretly picks the accent). Only the active tab, and never
    /// under `gap` (its slot is hidden entirely).
    enum AccentMode { case none, ring, edgeMark }

    var accentMode: AccentMode {
        guard isActive, style.activeIndicator != .gap else {
            return .none
        }
        return style.activeIndicator == .ring ? .ring : .edgeMark
    }

    /// The ring and edge mark both live on the `accent` subview
    /// (mutually exclusive); geometry is set in `layoutAccent`.
    /// The ring is a pure stroke (no fill) in the highlight
    /// color; the edge mark a filled bar.
    private func applyAccent() {
        layer?.borderWidth = 0
        switch accentMode {
        case .none:
            accent.isHidden = true
        case .ring:
            accent.isHidden = false
            accent.layer?.borderWidth = 2
            accent.layer?.borderColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
            accent.layer?.backgroundColor =
                NSColor.clear.cgColor
        case .edgeMark:
            accent.isHidden = false
            accent.layer?.borderWidth = 0
            accent.layer?.backgroundColor =
                NSColor(kiwiHex: style.highlightColor).cgColor
        }
    }
}
