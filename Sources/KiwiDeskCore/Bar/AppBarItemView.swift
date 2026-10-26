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
    let accent = SheenRimView()
    /// Where a partly visible window sits (#2234).
    let halfMoon = AppBarHalfMoon()
    /// The hover on glass, fading with the Fill (#2645): the bottom
    /// subview, under the content and the strokes.
    let hoverFill = GlassBackdrop()
    /// The box's border under Boxed (#1679): the bottom subview,
    /// so the active outline strokes over it.
    let boxBorder = ShelfBorder.makeSeated()
    /// Clips active accent indicator to item bounds (owner 2026-07-20).
    let accentClip = AppBarOverlay.PassThroughFlippedView()
    /// What draws over the outline — the count badge and the
    /// half-moon — riding with it (#2595).
    let aboveOutline = AppBarOverlay.PassThroughFlippedView()
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

    private(set) var windowID = WindowID(0)
    /// Owner application name for accessibility narration (#901).
    var name = ""
    /// Display text string (`KiwiCore.barItemText`).
    var text = ""
    var horizontal = true
    /// Concrete display edge derived from style.
    var edge: AppBarEdge { style.edge }
    private(set) var isActive = false
    private(set) var count = 1
    /// A float after the row's break (#1826): it reorders nothing,
    /// so a press never becomes a drag.
    private(set) var isFloatItem = false
    /// Core's verdict on where its window sits (#2234).
    private(set) var visibility: BarVisibility = .visible
    /// The windows its menu names (#1518); set beside `configure`.
    var members: [WindowID] = []
    /// Leading/trailing position within current item run; they
    /// set the rounded ends' insets (#1763).
    var isFirstInRun = false {
        didSet { if oldValue != isFirstInRun { needsLayout = true } }
    }
    var isLastInRun = false {
        didSet { if oldValue != isLastInRun { needsLayout = true } }
    }
    var isHovered = false
    var style = AppBarLook()
    var onSelect: (WindowID) -> Void = { _ in }
    /// Core's answers (#1514), the manager's one instance.
    weak var itemActions: AppBarItemActions?
    /// Core cut the title at `title_cap` (#1514).
    private(set) var titleCut = false
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
        addSubview(hoverFill)
        addSubview(iconView)
        addSubview(glyphLabel)
        addSubview(label)
        accentClip.addSubview(accent)
        aboveOutline.addSubview(badge)
        aboveOutline.addSubview(halfMoon)
        GlassBox.seatStrokes(strokes, of: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppBarItemView is code-only")
    }

    override func mouseDown(with event: NSEvent) {
        guard !openControlClickMenu(event) else { return }
        pressLocation = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressLocation, !isFloatItem else { return }
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
        // No press recorded: a Control-click's menu took it.
        guard pressLocation != nil else { return }
        defer { pressLocation = nil }
        if isDragging {
            isDragging = false
            onDragEnded(self)
        } else if let source = peekSource, source.opensOnClick {
            // A group's click opens its list and selects nothing
            // until a row is picked (#2571); a release off it — a
            // float group never drags — cancels, as a button (#2044).
            guard releasesInside(event) else { return }
            itemActions?.peek?.clicked(
                self,
                source: source,
                space: nil,
                edge: edge,
                clickCount: event.clickCount
            )
        } else if !isInert {
            onSelect(windowID)
        }
    }

    private func releasesInside(_ event: NSEvent) -> Bool {
        guard event.window != nil else { return true }
        return bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .mouseMoved, .activeAlways,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        refreshHover(event)
    }

    override func mouseMoved(with event: NSEvent) {
        refreshHover(event)
    }

    override func mouseExited(with event: NSEvent) {
        applyHover(false)
    }

    /// Hovered only while the pointer is on THIS view — a count
    /// drawn over the faded end takes the pointer there (#1517).
    private func refreshHover(_ event: NSEvent) {
        applyHover(BarHoverHit.owns(self, event))
    }

    /// Re-reads the hover from where the pointer rests (#1665).
    func syncHoverToPointer() {
        applyHover(BarHoverHit.ownsPointer(self))
    }

    private func applyHover(_ ownsPointer: Bool) {
        // The peek reads an inert item too: it may hide its title.
        reportPeek(ownsPointer: ownsPointer)
        // An item whose list is open stays lit until it closes (#2571).
        let open = itemActions?.peek?.holdsOpen(self) == true
        let hovered = !isInert && (ownsPointer || open)
        guard hovered != isHovered else { return }
        isHovered = hovered
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
        titleCut: Bool = false,
        floating: Bool = false,
        visibility: BarVisibility = .visible,
        active: Bool,
        horizontal: Bool,
        style: AppBarLook
    ) {
        windowID = id
        self.titleCut = titleCut
        self.name = name
        self.text = text
        self.count = count
        self.isFloatItem = floating
        self.visibility = visibility
        self.horizontal = horizontal
        self.isActive = active
        self.style = style
        isHovered = false
        iconView.image = icon
        let showsGlyph = glyph?.isEmpty == false
        glyphLabel.isHidden = !showsGlyph
        glyphLabel.stringValue = glyph ?? ""
        iconView.isHidden = showsGlyph || icon == nil
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
        } else if isFloatItem {
            updateFloatingAccessibilityLabel()
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

    /// A float's narration (#1826): the divider is visual only, so
    /// the float fact is spoken — one key per resulting sentence.
    private func updateFloatingAccessibilityLabel() {
        if !text.isEmpty && text != name {
            setAccessibilityLabel(
                L(
                    "app_bar.item_window_floating.ax",
                    "%1$@, floating window %2$@",
                    name,
                    text
                )
            )
        } else {
            setAccessibilityLabel(
                L(
                    "app_bar.item_app_floating.ax",
                    "%1$@, floating window",
                    name
                )
            )
        }
    }
}
