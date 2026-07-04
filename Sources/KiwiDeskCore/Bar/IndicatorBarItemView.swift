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
/// IndicatorBarItemView+Layout.swift.
final class IndicatorBarItemView: NSView {
    let iconView = NSImageView()
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
    private(set) var isActive = false
    private(set) var count = 1
    private var isHovered = false
    var params = MonocleParams()
    var onSelect: (WindowID) -> Void = { _ in }
    var onDragMoved: (IndicatorBarItemView, CGPoint) -> Void = { _, _ in }
    var onDragEnded: (IndicatorBarItemView) -> Void = { _ in }

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
        addSubview(label)
        addSubview(accent)
        addSubview(badge)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("IndicatorBarItemView is code-only")
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
        count: Int,
        active: Bool,
        horizontal: Bool,
        params: MonocleParams
    ) {
        windowID = id
        self.name = name
        self.count = count
        self.horizontal = horizontal
        self.isActive = active
        self.params = params
        isHovered = false
        iconView.image = icon
        iconView.isHidden =
            params.bar.content == .name || icon == nil
        label.isHidden = params.bar.content == .icon
        badge.isHidden = count < 2
        badge.stringValue = "\(count)"
        badge.textColor =
            NSColor(kiwiHex: params.bar.groupBadgeTextColor)
        badge.layer?.backgroundColor =
            NSColor(kiwiHex: params.bar.groupBadgeColor).cgColor
        applyColors()
        applyAccent()
        needsLayout = true
    }

    /// Hover swaps the box background (no overlay: a wash on
    /// top would muddy the icon and text) and the text color.
    private func applyColors() {
        label.textColor = NSColor(kiwiHex: textColorHex)
        layer?.backgroundColor =
            NSColor(kiwiHex: boxColorHex).cgColor
        // Pills round always; underline items only show their
        // box while hovered, rounded like a pill.
        let rounded =
            params.bar.style == .pills
            || (params.bar.style == .underline && isHovered)
        layer?.cornerRadius =
            rounded ? params.bar.cornerRadius : 0
    }

    private var textColorHex: String {
        if isHovered { return params.bar.hoverTextColor }
        return isActive
            ? params.bar.activeTextColor
            : params.bar.textColor
    }

    private var boxColorHex: String {
        if isHovered { return params.bar.hoverColor }
        switch params.bar.style {
        case .pills, .segments:
            return isActive
                ? params.bar.activeBoxColor
                : params.bar.boxColor
        case .underline:
            return "#00000000"
        }
    }

    /// One highlight color, three shapes: a ring around the
    /// active pill, an edge bar on the window-facing side of
    /// the active segment, the underline under the active
    /// name.
    private func applyAccent() {
        let highlighted =
            isActive && params.bar.activeStyle == .highlight
        if params.bar.style == .pills {
            layer?.borderWidth = highlighted ? 2 : 0
            layer?.borderColor =
                NSColor(
                    kiwiHex: params.bar.highlightColor
                ).cgColor
            accent.isHidden = true
            return
        }
        layer?.borderWidth = 0
        accent.isHidden = !highlighted
        accent.layer?.backgroundColor =
            NSColor(kiwiHex: params.bar.highlightColor).cgColor
    }
}

/// A text field cell that centers its text vertically.
final class IndicatorBarBadgeCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let minimumHeight = cellSize(forBounds: rect).height
        if titleRect.size.height > minimumHeight {
            titleRect.origin.y +=
                (titleRect.size.height - minimumHeight) / 2
            titleRect.size.height = minimumHeight
        }
        return titleRect
    }

    override func drawInterior(
        withFrame cellFrame: NSRect,
        in controlView: NSView
    ) {
        super.drawInterior(
            withFrame: titleRect(forBounds: cellFrame),
            in: controlView
        )
    }
}
