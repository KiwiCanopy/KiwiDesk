import AppKit

/// Interactive indicator bar item view representing an open
/// window. A collapsed GROUP item is inert to per-window verbs:
/// it stands for several windows, so a single-window action has
/// no one referent.
final class AppBarItemView: NSView {
    let iconView = NSImageView()
    /// SketchyBar font ligature icon label (#294, #901).
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
    /// Clips active accent indicator to item bounds (owner 2026-07-20).
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
    /// Owner application name for accessibility narration (#901).
    var name = ""
    /// Display text string (`KiwiCore.barItemText`).
    var text = ""
    var horizontal = true
    /// Concrete display edge derived from style.
    var edge: AppBarEdge { style.edge }
    private(set) var isActive = false
    private(set) var count = 1
    /// Leading/trailing position within current item run.
    var isFirstInRun = false
    var isLastInRun = false
    var isHovered = false
    var style = AppBarStyle()
    var onSelect: (WindowID) -> Void = { _ in }
    var onDragMoved: (AppBarItemView, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (AppBarItemView) -> Void = { _ in }

    private var pressLocation: NSPoint?
    private var isDragging = false

    private var isInert: Bool { isActive && count == 1 }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        // Scaled up and down to fit thick bars (owner 2026-07-20).
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

    /// Accessibility narration string (`AppBarAccessibilityTests`, #901,
    /// #937).
    private func updateAccessibilityLabel() {
        if count > 1 {
            setAccessibilityLabel(
                L(
                    "app_bar.group.ax",
                    "%1$@, windows: %2$d",
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
