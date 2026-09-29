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
        /// The windows this glyph stands for, in row order (#1528).
        var windows: [WindowID] = []
    }

    let identifierImage = NSImageView()
    let identifierLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    var appViews: [NSView] = []
    /// Glyphs a strip walk carries under a disc, fading, until the
    /// walk lands (#1528 item 21).
    var leavingViews: [NSView] = []
    var badgeViews: [NSTextField] = []
    var stickyBadgeViews: [StateBadgeView] = []
    var floatingBadgeViews: [StateBadgeView] = []
    let overflowBadge = SpaceBarItemView.makeBadge()
    /// The leading `+n` disc, before the glyphs (#1528 item 17).
    let leadingBadge = SpaceBarItemView.makeBadge()
    /// Click targets over the glyphs and each `+n` (#1528).
    var glyphTargets: [SpaceBarGlyphTarget] = []
    var overflowTarget: SpaceBarGlyphTarget?
    var leadingTarget: SpaceBarGlyphTarget?
    /// The target under the pointer, drawn like the focused glyph
    /// so a click target reads as one (#1528).
    var hoveredTarget: SpaceBarGlyphTarget?
    weak var glyphActions: SpaceBarGlyphActions?
    let heldBadge = StateBadgeView(symbolName: SpaceBarItemView.heldSymbol)
    /// Divider between identifier and app glyphs (QA 2026-07-19).
    let identifierDivider = NSView()
    let accent = SheenRimView()
    /// The box's border under Boxed (#1679): the bottom subview,
    /// so the active outline strokes over it.
    let boxBorder = ShelfBorder.make()
    /// Active mark corner clip (owner 2026-07-20).
    let accentClip = AppBarOverlay.FlippedView()
    /// The run's ends: they set the rounded ends' insets (#1763).
    var isFirstInRun = false {
        didSet { if oldValue != isFirstInRun { needsLayout = true } }
    }
    var isLastInRun = false {
        didSet { if oldValue != isLastInRun { needsLayout = true } }
    }

    private(set) var identity = Identity.space(SpaceID("1"))
    var space: SpaceID? { identity.space }
    private(set) var spaceGlyph = SpaceGlyph.text(
        "?",
        tinted: true
    )
    private(set) var apps: [App] = []
    /// The `+n` discs before and after the glyphs (#1528, #376).
    private(set) var before = SpaceBarStrip.Disc.none
    private(set) var after = SpaceBarStrip.Disc.none
    var overflow: Int { after.windows.count }
    var overflowWindows: [WindowID] { after.windows }
    var focusInOverflow: Bool { after.holdsFocus }
    var overflowBefore: [WindowID] { before.windows }
    var focusBefore: Bool { before.holdsFocus }
    /// The groups drawn (#1528 item 21).
    private(set) var drawn: SpaceBarStrip.Drawn?
    /// The walk the next layout plays, when the strip moved under
    /// a Space it kept (#1528 item 21).
    var pendingWalk: SpaceBarStrip.Walk?
    /// Whether the pointer rests on the chip — the hold's
    /// reading, the active chip's too (#1528 item 21).
    var pointerInside = false
    /// Reports the pointer entering or leaving a Space chip with
    /// the strip it drew; the manager holds that strip.
    var onPointerInside: (SpaceID, SpaceBarStrip.Drawn?, Bool) -> Void = {
        _,
        _,
        _ in
    }
    private(set) var held: Held?
    /// What this item draws in place of its glyphs (#1683).
    private(set) var collapse: Collapse?
    private(set) var isActive = false
    var isHovered = false
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
        boxBorder.autoresizingMask = [.width, .height]
        addSubview(boxBorder)
        addSubview(identifierImage)
        addSubview(identifierLabel)
        addSubview(identifierDivider)
        addSubview(overflowBadge)
        addSubview(leadingBadge)
        addSubview(heldBadge)
        addSubview(accentClip)
        accentClip.addSubview(accent)
        springRing.fillColor = nil
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

    func configure(
        identity: Identity,
        spaceGlyph: SpaceGlyph,
        apps: [App],
        active: Bool,
        horizontal: Bool,
        style: SpaceBarLook,
        stateMarkColors: StateMarkColors,
        before: SpaceBarStrip.Disc = .none,
        after: SpaceBarStrip.Disc = .none,
        drawn: SpaceBarStrip.Drawn? = nil,
        held: Held? = nil,
        collapse: Collapse? = nil
    ) {
        let keepsSpace =
            self.identity == identity && self.collapse == nil
            && collapse == nil
        let walk =
            keepsSpace
            ? SpaceBarStrip.Walk.between(
                self.drawn,
                leadingDisc: !self.before.windows.isEmpty,
                drawn,
                leadingDisc: !before.windows.isEmpty
            ) : nil
        // A render repeating the strip keeps what the last one
        // started — a walk not yet laid out (a menu pick lays out
        // late) and the glyphs still fading out (#1528 item 21).
        let repeats = keepsSpace && walk == nil && self.drawn == drawn
        if !repeats { pendingWalk = walk }
        if self.identity != identity {
            cancelSpringSweep()
            isDragHovered = false
            // A pointer resting on the Space this slot drew must
            // not leave its hover fill under the layer glyph.
            isHovered = false
            // Nor its strip hold: the slot no longer draws that
            // Space, so no exit would ever release it (#1528).
            setPointerInside(false)
        }
        self.identity = identity
        self.spaceGlyph = spaceGlyph
        self.apps = apps
        self.before = before
        self.after = after
        self.drawn = drawn
        self.held = held
        self.collapse = collapse
        self.isActive = active
        self.horizontal = horizontal
        self.style = style
        self.stateMarkColors = stateMarkColors
        syncAppViews(startsWalk: walk != nil, keepsLeaving: repeats)
        syncTargets()
        restyle()
        needsLayout = true
        setAccessibilityElement(true)
        setAccessibilityRole(space == nil ? .image : .button)
        setAccessibilityLabel(axLabel)
    }

    private func syncAppViews(startsWalk: Bool, keepsLeaving: Bool) {
        // A walk keeps the glyphs it carries off, so they fade
        // under their disc rather than vanish (#1528 item 21).
        let leaving =
            startsWalk ? Self.leaving(appViews, walk: pendingWalk) : []
        if !keepsLeaving {
            leavingViews.forEach { $0.removeFromSuperview() }
            leavingViews = leaving
        }
        appViews.filter { view in
            !leaving.contains { $0 === view }
        }.forEach { $0.removeFromSuperview() }
        badgeViews.forEach { $0.removeFromSuperview() }
        stickyBadgeViews.forEach { $0.removeFromSuperview() }
        floatingBadgeViews.forEach { $0.removeFromSuperview() }
        appViews = apps.map { app in
            // Beneath the discs, which a walking glyph passes under.
            if app.glyph != nil {
                let tf = NSTextField(labelWithString: "")
                tf.alignment = .center
                tf.setAccessibilityElement(false)
                addSubview(tf, positioned: .below, relativeTo: overflowBadge)
                return tf
            }
            let iv = NSImageView()
            iv.image = app.icon
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.setAccessibilityElement(false)
            addSubview(iv, positioned: .below, relativeTo: overflowBadge)
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
