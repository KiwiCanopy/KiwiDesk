import AppKit

/// One entry in the indicator bar: an optional app icon and
/// the window's title centered in the slot, a style-dependent
/// accent
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
    /// bar's text colors, and explicitly not an AX element so
    /// the ligature's raw name is never spoken (#901).
    let glyphLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let label: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let accent = NSView()
    /// Rounds/clips only the active mark (and ring) to the item's
    /// corner without clipping the item itself — so the mark cuts on
    /// the curve while the corner badge stays whole (owner
    /// 2026-07-20). Covers the item bounds; the accent lives inside.
    /// Flipped to match the item, so the accent's y math is unchanged.
    let accentClip = AppBarOverlay.FlippedView()
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
    /// The app's name, used for VoiceOver accessible name
    /// generation (#901).
    var name = ""
    /// The string the label draws, resolved by the driver
    /// (`KiwiCore.barItemText`): the capped window title, or the
    /// app name where a title cannot speak.
    var text = ""
    var horizontal = true
    /// The concrete edge the bar sits on (from the resolved
    /// style); the active edge-mark hugs it.
    var edge: AppBarEdge { style.edge }
    private(set) var isActive = false
    private(set) var count = 1
    /// Whether this item sits at the run's leading / trailing end.
    /// Set by the overlay each render (index 0 / last). Under Plain
    /// the shared plate rounds only there, so only these items clip
    /// their outer corner; Boxed clips every item (its own box).
    var isFirstInRun = false
    var isLastInRun = false
    /// Internal, not private: the painting half lives in
    /// `AppBarItemView+Paint.swift` and reads it.
    var isHovered = false
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
        // The item is a click target with a button role; its
        // subviews stay silent so VoiceOver speaks once (#901).
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        // Scale the app icon up as well as down: the default
        // `scaleProportionallyDown` capped it at the image's native
        // size, so it stopped growing on thick bars (owner
        // 2026-07-20). App icons carry high-res reps, so upscaling
        // to the slot stays crisp.
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setAccessibilityElement(false)
        accent.wantsLayer = true
        accentClip.wantsLayer = true
        label.alignment = .center
        badge.wantsLayer = true
        badge.alignment = .center
        badge.setAccessibilityElement(false)
        addSubview(iconView)
        addSubview(glyphLabel)
        addSubview(label)
        addSubview(accentClip)
        accentClip.addSubview(accent)
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
        guard isDragging else { return }
        // Window-space point; the overlay maps it into the item
        // container's coordinates. Not the item's own `superview`:
        // under per-box glass the item is nested in a glass wrapper,
        // so its superview is not the run's coordinate space.
        onDragMoved(self, location)
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
        name: String = "",
        text: String,
        icon: NSImage?,
        glyph: String?,
        count: Int,
        active: Bool,
        horizontal: Bool,
        style: AppBarStyle
    ) {
        windowID = id
        self.name = name
        self.text = text
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
            glyph?.isEmpty == false && content != .title
        glyphLabel.isHidden = !showsGlyph
        glyphLabel.stringValue = glyph ?? ""
        iconView.isHidden =
            showsGlyph || content == .title
            || icon == nil
        badge.isHidden = count < 2
        badge.stringValue = "\(count)"
        badge.textColor =
            NSColor(kiwiHex: style.groupBadgeTextColor)
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: style.groupBadgeColor).cgColor
        applyColors()
        applyAccent()
        updateAccessibilityLabel()
        needsLayout = true
    }

    /// Names the app and, when a title is drawn, the window;
    /// collapsed groups name the app and count (#901).
    private func updateAccessibilityLabel() {
        if count > 1 {
            setAccessibilityLabel(
                L(
                    "app_bar.group.ax",
                    "%1$@, %2$d windows",
                    name,
                    count
                )
            )
        } else if !text.isEmpty && text != name {
            setAccessibilityLabel(
                L(
                    "app_bar.item_window.ax",
                    "%1$@, window %2$@",
                    name,
                    text
                )
            )
        } else {
            setAccessibilityLabel(
                L(
                    "app_bar.item_app.ax",
                    "%1$@",
                    name
                )
            )
        }
    }
}
