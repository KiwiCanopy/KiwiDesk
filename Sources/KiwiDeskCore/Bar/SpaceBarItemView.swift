import AppKit

/// Space item view in Space Bar with identifier and app glyphs (#293).
final class SpaceBarItemView: NSView {
    /// Space identifier glyph representation.
    enum Identifier: Equatable {
        case symbol(String)
        case text(String, tinted: Bool)
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
    /// Divider between identifier and app glyphs (QA 2026-07-19).
    let identifierDivider = NSView()
    let accent = NSView()
    /// Active mark corner clip (owner 2026-07-20).
    let accentClip = AppBarOverlay.FlippedView()
    var isFirstInRun = false
    var isLastInRun = false

    private(set) var space = SpaceID("1")
    private(set) var spaceGlyph = Identifier.text(
        "?",
        tinted: true
    )
    private(set) var apps: [App] = []
    private(set) var overflow = 0
    /// True if focused window is in overflow (#376).
    private(set) var focusInOverflow = false
    private(set) var isActive = false
    private(set) var isHovered = false
    /// Drag hover state (#372).
    var isDragHovered = false
    /// Spring sweep ring (#372).
    let springRing = CAShapeLayer()
    var horizontal = true
    var style = SpaceBarStyle()
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
        guard !isActive else { return }
        onSelect(space)
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
        guard !isActive else { return }
        isHovered = true
        restyle()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        restyle()
    }

    func configure(
        space: SpaceID,
        spaceGlyph: Identifier,
        apps: [App],
        active: Bool,
        horizontal: Bool,
        style: SpaceBarStyle,
        stateMarkColors: StateMarkColors,
        overflow: Int = 0,
        focusInOverflow: Bool = false
    ) {
        if self.space != space {
            cancelSpringSweep()
            isDragHovered = false
        }
        self.space = space
        self.spaceGlyph = spaceGlyph
        self.apps = apps
        self.overflow = overflow
        self.focusInOverflow = focusInOverflow
        self.isActive = active
        self.horizontal = horizontal
        self.style = style
        self.stateMarkColors = stateMarkColors
        syncAppViews()
        restyle()
        needsLayout = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(axLabel)
    }

    private var axLabel: String {
        let windows =
            apps.reduce(0) { $0 + $1.count } + overflow
        let name = L(
            "space_bar.item.ax.space",
            "Space %1$@, %2$d applications",
            space.raw,
            windows
        )
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
