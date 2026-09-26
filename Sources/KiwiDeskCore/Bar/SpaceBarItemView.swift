import AppKit

/// Space item view in Space Bar with identifier and app glyphs (#293).
final class SpaceBarItemView: NSView {
    /// What an item stands for (#1169). A layer item shows
    /// the active shortcut layer: never a click, drag or drop
    /// target, and never the active slot.
    enum Identity: Equatable {
        case space(SpaceID)
        case layer(String)

        /// The Space the item selects; nil for a layer item —
        /// the one projection every Space-keyed channel asks.
        var space: SpaceID? {
            if case .space(let id) = self { return id }
            return nil
        }
    }

    /// App glyph run in space item (#293 stage 2, #294, #414, #445).
    struct App: Equatable {
        let name: String
        var title: String?
        let icon: NSImage?
        let glyph: String?
        let focused: Bool
        let count: Int
        var sticky = false
        var floating = false
        var stickyScope: StickyScope = .none
    }

    let identifierImage = NSImageView()
    let identifierLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    var appViews: [NSView] = []
    var badgeViews: [NSTextField] = []
    var stickyBadgeViews: [StateBadgeView] = []
    var floatingBadgeViews: [StateBadgeView] = []
    let overflowBadge = SpaceBarItemView.makeBadge()
    let heldBadge = StateBadgeView(symbolName: SpaceBarItemView.heldSymbol)
    /// Divider between identifier and app glyphs (QA 2026-07-19).
    let identifierDivider = NSView()
    let accent = NSView()
    /// Active mark corner clip (owner 2026-07-20).
    let accentClip = AppBarOverlay.FlippedView()
    var isFirstInRun = false
    var isLastInRun = false

    private(set) var identity = Identity.space(SpaceID("1"))
    var space: SpaceID? { identity.space }
    private(set) var spaceGlyph = SpaceGlyph.text(
        "?",
        tinted: true
    )
    private(set) var apps: [App] = []
    private(set) var overflow = 0
    /// True if focused window is in overflow (#376).
    private(set) var focusInOverflow = false
    private(set) var held: Held?
    private(set) var isActive = false
    private(set) var isHovered = false
    /// Drag hover state (#372).
    var isDragHovered = false
    /// Spring sweep ring (#372).
    let springRing = CAShapeLayer()
    var horizontal = true
    var style = SpaceBarLook()
    /// State mark colors (#429).
    var stateMarkColors = StateMarkColors(sticky: "", floating: "")
    var onSelect: (SpaceID) -> Void = { _ in }

    override var isFlipped: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        accent.wantsLayer = true
        accentClip.wantsLayer = true
        identifierDivider.wantsLayer = true
        addSubview(identifierImage)
        addSubview(identifierLabel)
        addSubview(identifierDivider)
        addSubview(overflowBadge)
        addSubview(heldBadge)
        addSubview(accentClip)
        accentClip.addSubview(accent)
        springRing.fillColor = nil
        springRing.lineWidth = 2
        springRing.strokeEnd = 0
        springRing.isHidden = true
        layer?.addSublayer(springRing)
    }

    /// Creates badge label with circular indicator background.
    static func makeBadge() -> NSTextField {
        let tf = NSTextField(labelWithString: "")
        let cell = IndicatorBarBadgeCell(textCell: "")
        cell.alignment = .center
        cell.isEditable = false
        cell.isSelectable = false
        cell.isBordered = false
        cell.isBezeled = false
        cell.drawsBackground = false
        tf.cell = cell
        tf.wantsLayer = true
        tf.setAccessibilityElement(false)
        return tf
    }

    static let floatingSymbol = FloatingStyle.symbolName

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        guard !isActive, let space else { return }
        onSelect(space)
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
        guard isHovered else { return }
        isHovered = false
        restyle()
    }

    /// Hovered only while the pointer is on THIS view — a count
    /// drawn over the faded end takes the pointer there (#1517);
    /// the hover fill promises a click, and a layer item has none.
    private func refreshHover(_ event: NSEvent) {
        applyHover(BarHoverHit.owns(self, event))
    }

    /// Re-reads the hover from where the pointer rests (#1665) —
    /// the shelf's placement moves a chip without an exit event.
    func syncHoverToPointer() {
        applyHover(BarHoverHit.ownsPointer(self))
    }

    private func applyHover(_ ownsPointer: Bool) {
        let hovered = !isActive && space != nil && ownsPointer
        guard hovered != isHovered else { return }
        isHovered = hovered
        restyle()
    }

    func configure(
        identity: Identity,
        spaceGlyph: SpaceGlyph,
        apps: [App],
        active: Bool,
        horizontal: Bool,
        style: SpaceBarLook,
        stateMarkColors: StateMarkColors,
        overflow: Int = 0,
        focusInOverflow: Bool = false,
        held: Held? = nil
    ) {
        if self.identity != identity {
            cancelSpringSweep()
            isDragHovered = false
            // A pointer resting on the Space this slot drew must
            // not leave its hover fill under the layer glyph.
            isHovered = false
        }
        self.identity = identity
        self.spaceGlyph = spaceGlyph
        self.apps = apps
        self.overflow = overflow
        self.focusInOverflow = focusInOverflow
        self.held = held
        self.isActive = active
        self.horizontal = horizontal
        self.style = style
        self.stateMarkColors = stateMarkColors
        syncAppViews()
        restyle()
        needsLayout = true
        setAccessibilityElement(true)
        setAccessibilityRole(space == nil ? .image : .button)
        setAccessibilityLabel(axLabel)
    }

    /// Announced whatever the glyph draws (bars.md): a layer
    /// item names its layer, a Space item its Space and count.
    private var axLabel: String {
        let space: SpaceID
        switch identity {
        case .layer(let layer):
            return L(
                "space_bar.item.ax.layer",
                "Shortcut layer %1$@",
                layer
            )
        case .space(let id):
            space = id
        }
        let windows =
            apps.reduce(0) { $0 + $1.count } + overflow
        let name = spaceName(space, windows: windows)
        return isActive
            ? L(
                "space_bar.item.ax.current",
                "%1$@, current",
                name
            )
            : L(
                "space_bar.item.ax.not_current",
                "%1$@, not current",
                name
            )
    }

    private func syncAppViews() {
        appViews.forEach { $0.removeFromSuperview() }
        badgeViews.forEach { $0.removeFromSuperview() }
        stickyBadgeViews.forEach { $0.removeFromSuperview() }
        floatingBadgeViews.forEach { $0.removeFromSuperview() }
        appViews = apps.map { app in
            if app.glyph != nil {
                let tf = NSTextField(labelWithString: "")
                tf.alignment = .center
                tf.setAccessibilityElement(false)
                addSubview(tf)
                return tf
            }
            let iv = NSImageView()
            iv.image = app.icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.setAccessibilityElement(false)
            addSubview(iv)
            return iv
        }
        badgeViews = apps.map { _ in
            let badge = Self.makeBadge()
            addSubview(badge)
            return badge
        }
        stickyBadgeViews = apps.map { app in
            let badge = StateBadgeView(
                symbolName: StickyStyle.symbolName(
                    for: app.stickyScope
                ) ?? StickyStyle.symbolName
            )
            addSubview(badge)
            return badge
        }
        floatingBadgeViews = apps.map { _ in
            let badge = StateBadgeView(
                symbolName: Self.floatingSymbol
            )
            addSubview(badge)
            return badge
        }
    }
}
