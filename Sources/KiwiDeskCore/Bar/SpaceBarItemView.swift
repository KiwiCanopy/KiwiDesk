import AppKit

/// One Space in the Space Bar (#293): the space's identifier
/// glyph followed by a compact row (horizontal bar) or column
/// (vertical bar) of app glyphs for the windows currently in
/// that space. Click focuses the space; app glyphs are
/// informational in v1 — never nested click targets.
///
/// Two-accent rendering: inactive spaces draw everything in
/// `itemColor`; the active space draws identifier + glyphs in
/// `activeItemColor`, and the focused window's glyph in
/// `focusedItemColor`. Emoji identifiers and native app images
/// stay untinted — shape (the active indicator) carries the
/// active state there.
final class SpaceBarItemView: NSView {
    /// The space identifier, resolved by the driver.
    enum Identifier: Equatable {
        /// A template SF Symbol, tinted by space state.
        case symbol(String)
        /// Emoji or single character; emoji render untinted.
        case text(String, tinted: Bool)
    }

    /// One app glyph in the space's row — one slot per
    /// adjacent same-app run (#293 stage 2), wearing a count
    /// badge when the run holds several windows. No
    /// focused-inside expansion: glyphs aren't click targets,
    /// so a group containing the focused window just takes the
    /// focused accent.
    struct App: Equatable {
        let name: String
        let icon: NSImage?
        /// App Font ligature; non-nil replaces `icon` and
        /// follows the text-color ladder (#294).
        let glyph: String?
        let focused: Bool
        /// Windows behind this glyph; > 1 shows a count badge.
        let count: Int
        /// State badges (#414): aggregates over the run — an
        /// explicit "at least one" signal, honest for a group
        /// (badge inheritance). Sticky wears the top-left
        /// badge, floating the bottom-left; the group count
        /// keeps top-right. Space Bar only — in the bar there
        /// is otherwise no way to tell these states apart.
        var sticky = false
        var floating = false
        /// The sticky SCOPE the badge glyph reflects (#445):
        /// `.global` → `infinity`, `.display` → `pin.fill`. The
        /// run's first sticky member wins (badge inheritance); a
        /// mixed run is rare and either glyph reads as "sticky".
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
    /// One count badge per glyph slot (hidden below 2).
    var badgeViews: [NSTextField] = []
    /// Per-slot state badges (#414): sticky top-left, floating
    /// bottom-left — the count badge's circular plate wearing a
    /// symbol, so all three corners read as one badge family.
    var stickyBadgeViews: [StateBadgeView] = []
    var floatingBadgeViews: [StateBadgeView] = []
    /// The "+n" overflow badge, its own trailing slot.
    let overflowBadge = SpaceBarItemView.makeBadge()
    /// The identifier↔glyphs rule (QA 2026-07-19) — the front
    /// segment's divider, reused inside the item. Hidden on
    /// empty spaces (nothing to separate).
    let identifierDivider = NSView()
    let accent = NSView()
    /// Rounds/clips only the active mark to the item's corner
    /// without clipping the item itself — so the mark cuts on the
    /// curve while corner badges stay whole (owner 2026-07-20).
    /// Flipped to match the item, so the accent's y math is unchanged.
    let accentClip = AppBarOverlay.FlippedView()
    /// Whether this item sits at the run's leading / trailing end.
    /// Under Plain the shared plate rounds only there. The trailing
    /// end may be the front-app segment's, not the last item's, so
    /// the overlay sets `isLastInRun` false when a front app trails.
    var isFirstInRun = false
    var isLastInRun = false

    private(set) var space = SpaceID("1")
    private(set) var spaceGlyph = Identifier.text(
        "?",
        tinted: true
    )
    private(set) var apps: [App] = []
    private(set) var overflow = 0
    /// The focused window is hidden past the cap (its glyph isn't
    /// visible) — the "+n" tints to signal focus is behind it (#376).
    private(set) var focusInOverflow = false
    private(set) var isActive = false
    private(set) var isHovered = false
    /// Synthetic hover during a window drag (#372). Tracking
    /// areas stay silent while another app owns the drag loop,
    /// so the driver sets this from the AX cursor position; it
    /// routes through the same `hoverFillColor` path as `isHovered`.
    /// Mutated via `setDragHover` (SpaceBarItemView+DragDrop).
    var isDragHovered = false
    /// The pending-spring sweep ring (#372): a stroke that fills
    /// 0→1 over the dwell, layered on top of the hover tint.
    let springRing = CAShapeLayer()
    var horizontal = true
    var style = SpaceBarStyle()
    /// The sticky / floating badge tints (#429), resolved by
    /// `KiwiCore`; the state badges' glyphs read these instead of
    /// the count badge's `groupBadgeColor` family.
    var stateMarkColors = StateMarkColors(sticky: "", floating: "")
    var onSelect: (SpaceID) -> Void = { _ in }

    /// Flipped so the identifier leads at the visual top on
    /// vertical bars and glyphs read in flat-array order (same
    /// convention as `AppBarOverlay.FlippedView`).
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

    /// The App Bar's badge shape: a filled circle around a
    /// bold centered count (`IndicatorBarBadgeCell`).
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

    /// The floating badge's mark, read from the style that owns
    /// it (`FloatingStyle.symbolName`) — the sticky mark is
    /// shared with the on-window mark the same way, see
    /// `StickyStyle.symbolName`.
    static let floatingSymbol = FloatingStyle.symbolName

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Interaction

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

    // MARK: - Configuration

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
        // A pooled view reused for a different Space drops any
        // drag-drop cues it was showing for the old one — a stale
        // hover tint or half-swept spring ring would otherwise
        // paint on the wrong item (#372, review).
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
        // Hover is NOT reset here: a retile under the pointer
        // (focus changes are frequent) must not drop the tint —
        // mouseExited still fires when the pointer leaves.
        syncAppViews()
        restyle()
        needsLayout = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(axLabel)
    }

    private var axLabel: String {
        // Windows, not visible slots: grouped and past-the-cap
        // windows still count.
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

    /// One subview per app: a text field for App Font glyphs, an
    /// image view otherwise. Recreating (not pooling) is
    /// load-bearing: `styleApps` never re-sets an image view's
    /// `image`, so naive reuse would show stale icons.
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

    // Styling lives in SpaceBarItemView+Style.swift;
    // layout in SpaceBarItemView+Layout.swift.
}
