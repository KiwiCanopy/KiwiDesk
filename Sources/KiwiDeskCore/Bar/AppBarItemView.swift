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
    /// The untinted native icon, kept so state color changes
    /// (hover, focus) can re-tint from the original (#294).
    private var originalIcon: NSImage?
    var name = ""
    var horizontal = true
    /// The concrete edge the bar sits on; the active edge-mark
    /// hugs it.
    var edge: AppBarEdge = .top
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
        style: AppBarStyle,
        edge: AppBarEdge
    ) {
        windowID = id
        self.name = name
        self.count = count
        self.horizontal = horizontal
        self.edge = edge
        self.isActive = active
        self.style = style
        isHovered = false
        originalIcon = icon
        let showsGlyph =
            glyph != nil && style.content != .name
        glyphLabel.isHidden = !showsGlyph
        glyphLabel.stringValue = glyph ?? ""
        iconView.isHidden =
            showsGlyph || style.content == .name
            || icon == nil
        label.isHidden = style.content == .icon
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
        applyIcon()
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        applyCornerRadius()
    }

    /// Icon recoloring per source (#294). `tinted_image` — and
    /// the glyph mode's no-glyph fallback, so a glyph bar
    /// stays monochrome — recolor the native image into the
    /// state text color (normal/active/hover), the same ladder
    /// the glyphs and labels follow; re-run on every state
    /// color change. Tinted additionally honors
    /// `tint_appearance`: a dark ramp renders the icon dark
    /// (for light bars); `auto` follows the system appearance.
    private func applyIcon() {
        guard !iconView.isHidden,
            let icon = originalIcon
        else { return }
        iconView.image =
            style.iconSource == .appImage
            ? icon
            : icon.kiwiTinted(
                with: NSColor(kiwiHex: textColorHex),
                darkRamp: style.iconSource == .tintedImage
                    && resolvedDarkRamp
            )
    }

    /// `auto` = contrast the system appearance, like the
    /// system's Tinted icon style: light mode gets dark icons,
    /// dark mode light ones.
    private var resolvedDarkRamp: Bool {
        switch style.tintAppearance {
        case .light: return false
        case .dark: return true
        case .auto:
            return effectiveAppearance.bestMatch(
                from: [.aqua, .darkAqua]
            ) == .aqua
        }
    }

    /// Re-resolve `auto` tinting when the system appearance
    /// flips while the bar is showing.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColors()
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
        return style.tabBackground == .boxed
    }

    // The settings App Bar preview (`AppBarPreviewStrip`, GUI
    // target) is a schematic twin of this box/accent logic —
    // keep the two in step when the box or accent rules change.
    private var boxColorHex: String {
        if isHovered { return style.hoverColor }
        switch style.tabBackground {
        case .boxed:
            return isActive
                ? style.activeBoxColor
                : style.boxColor
        case .plain:
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
