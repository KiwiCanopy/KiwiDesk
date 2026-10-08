import AppKit

/// The Space Bar's section of one display's shelf (#293, #385,
/// #1517): it draws into `root`, which `ShelfOverlay` places on
/// the shelf's one panel over the shelf's one plate.
@MainActor
public final class SpaceBarOverlay {
    /// One Space's resolved content — or the active shortcut
    /// layer's, ahead of the Spaces (#1169).
    public struct Item {
        let identity: SpaceBarItemView.Identity
        let spaceGlyph: SpaceGlyph
        private(set) var apps: [SpaceBarItemView.App]
        let active: Bool
        /// The `+N` disc after the drawn glyphs — its menu lists
        /// the windows it hides (#1528, #376).
        private(set) var after: SpaceBarStrip.Disc
        /// The disc before them (#1528 item 17).
        private(set) var before: SpaceBarStrip.Disc = .none
        /// The groups drawn, which a chip under the pointer holds
        /// (#1528 item 21); nil for a layer item.
        private(set) var drawn: SpaceBarStrip.Drawn?
        /// The `+N` discs drawn, one per side that hides windows.
        var discs: Int {
            (before.windows.isEmpty ? 0 : 1)
                + (after.windows.isEmpty ? 0 : 1)
        }
        /// Set only by `collapsed(to:)` (#1683).
        private(set) var collapse: SpaceBarItemView.Collapse?
        /// The held or temporary Space marker (#1507, #1790).
        var marker: SpaceBarItemView.Marker?

        /// Where a held Space came from (#1507).
        var held: SpaceBarItemView.Held? {
            if case .held(let held) = marker { return held }
            return nil
        }

        init(
            space: SpaceID,
            spaceGlyph: SpaceGlyph,
            apps: [SpaceBarItemView.App],
            active: Bool,
            before: SpaceBarStrip.Disc = .none,
            after: SpaceBarStrip.Disc,
            drawn: SpaceBarStrip.Drawn? = nil
        ) {
            identity = .space(space)
            self.spaceGlyph = spaceGlyph
            self.apps = apps
            self.active = active
            self.before = before
            self.after = after
            self.drawn = drawn
        }

        /// The layer item: one glyph, no apps, never active.
        init(
            layer: String,
            glyph: SpaceGlyph
        ) {
            identity = .layer(layer)
            spaceGlyph = glyph
            apps = []
            active = false
            after = .none
        }

        var space: SpaceID? { identity.space }

        /// The one collapse decision (#1683): an item its screen
        /// does not show draws `content`, so the length the
        /// shelf plans and the one the render draws both read
        /// the result. The shown item, a layer item and `.apps`
        /// pass unchanged. The count is what the corner disc
        /// draws and the label announces; the state badges
        /// go with the glyphs, and the discs with them.
        func collapsed(
            to content: SpaceBarStyle.InactiveContent
        ) -> Self {
            guard !active, space != nil, collapse == nil else {
                return self
            }
            let windows =
                apps.reduce(0) { $0 + $1.count } + after.windows.count
                + before.windows.count
            var item = self
            item.apps = []
            item.after = .none
            item.before = .none
            // It draws no strip, so it has none to hold.
            item.drawn = nil
            switch content {
            case .apps:
                return self
            case .count:
                item.collapse = .init(windows: windows)
            }
            return item
        }
    }

    /// Click-to-focus hook; wired to `KiwiCore.focusSpace`.
    public var onSelect: @MainActor (SpaceID) -> Void = { _ in }
    /// The pointer entering or leaving a Space chip, with the
    /// strip it drew — the manager's hold (#1528 item 21).
    var onStripHover:
        @MainActor (SpaceID, SpaceBarStrip.Drawn?, Bool) -> Void = {
            _,
            _,
            _ in
        }
    /// The glyph targets' answers, the manager's one instance.
    var glyphActions: SpaceBarGlyphActions?
    /// The bars' context menus (#1518): held by the section root,
    /// which every view in the section finds by walking up.
    weak var contextMenus: BarContextMenus? {
        didSet { root.contextMenus = contextMenus }
    }

    /// The section's view; the shelf sets its origin, the
    /// section its size.
    let root = ShelfSectionRoot()
    /// The plate this section's run asks for, in `root`'s
    /// coordinates — the shelf unions it with the other section's.
    var plateFrame: CGRect = .zero
    /// The span this section's run draws, in `root`'s coordinates —
    /// what the shelf's section divider centres against (#1779).
    var contentFrame: CGRect = .zero
    /// Fires after every render, so the shelf re-lays its plate.
    var onRendered: @MainActor () -> Void = {}
    var itemViews: [SpaceBarItemView] = []
    /// Clipping item viewport (#385).
    let itemContainer = AppBarOverlay.FlippedView()
    /// Holds the run — items, their glass, the layer rule and an
    /// unpinned front segment — inside `itemContainer`; a scroll
    /// moves this one view, never each item.
    let itemRun = AppBarOverlay.FlippedView()
    /// What a scroll re-reads without a render.
    var scrollRun: ScrollRun?
    /// Where the last render placed the front segment, which a
    /// content redraw keeps (#2086).
    var frontPlacement: FrontPlacement?
    /// The front segment is gliding shut (#1903); a render that
    /// draws it again ends the shrink.
    var frontLeaving = false
    /// Where the front name's slot ends, which the chip reaches to
    /// whatever the name's own width (#2086).
    var frontNameEnd: CGFloat = 0
    /// Hidden-entry counts on each fading end (#1517).
    let backCount = ShelfCountView(side: .before)
    let forwardCount = ShelfCountView(side: .after)
    /// Host view for front-app segment (#409).
    weak var frontHost: NSView?
    /// Per-box Liquid Glass views for `boxed + liquid_glass`.
    var boxGlasses: [NSView] = []
    /// Colored backdrops behind per-box glass (#408).
    var boxTints: [GlassBackdrop] = []
    /// Front-app segment frosted backdrop box.
    var frontGlass: NSView?
    /// Colored backdrop behind front segment glass (#408).
    var frontTint: GlassBackdrop?
    /// Whole-bar scroll offset (#385).
    var scrollOffset: CGFloat = 0
    /// The Space the last render expanded and the items it drew
    /// (#1683), so a switch is told from a render that keeps it.
    var shownExpanded: SpaceID?
    var shownIdentities: [SpaceBarItemView.Identity] = []
    /// The one frame write a run item, its box glass and that
    /// glass's backdrop take; a test swaps it to see whether a
    /// pass asked to travel.
    var moveFrame: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    /// Follows the active Space unless a manual scroll holds.
    var follow = ShelfFollow<SpaceID>()
    /// Cached scroll geometry for hit-testing and autoscroll (#385).
    var scrollGeom: ScrollGeom?
    /// Running drag-autoscroll task when dwelling on an arrow
    /// zone (#385). A `Task` loop, not a `Timer`: a `Timer`'s
    /// `@Sendable` block cannot weak-capture this non-`Sendable`
    /// `@MainActor` type in a release build.
    var autoScrollTask: Task<Void, Never>?
    var autoScrollDirection: ScrollDirection?
    /// Last-rendered strip in AX coordinates and the per-item
    /// frames within it (strip-local, top-left), for the #372
    /// drag-drop hit test. Kept in lockstep with what `render()`
    /// drew — clamped to the visible viewport so a point over an
    /// arrow zone or a scrolled-off item is never a drop target.
    var hitStrip: CGRect = .zero
    var hitFrames: [(space: SpaceID, frame: CGRect)] = []
    /// Section rule after the layer item (#1169).
    let layerDivider: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.isHidden = true
        return view
    }()
    // Optional trailing front-app segment (#293).
    let frontBox = NSView()
    /// The windows the shown front-app segment stands for (#2024).
    var frontWindows: [WindowID] = []
    /// The chip's border (#1679), above its box or glass.
    let frontBorder = ShelfBorder.make()
    /// The chip's active indicator (#1856), clipped to the chip,
    /// above its border.
    let frontAccent = SheenRimView()
    let frontAccentClip = AppBarOverlay.FlippedView()
    let frontDivider = NSView()
    let frontIcon = FrontChipIcon()
    let frontGlyph: FrontChipGlyph = {
        let tf = FrontChipGlyph(labelWithString: "")
        tf.alignment = .center
        tf.setAccessibilityElement(false)
        return tf
    }()
    let frontName = NSTextField(labelWithString: "")
    /// One show's input, compared whole to skip a repeat (#1901).
    struct Shown: Equatable {
        let items: [Item]
        let frontApp: SpaceBarItemView.App?
        let strip: CGRect
        let style: SpaceBarLook
        let stateMarkColors: StateMarkColors
    }

    var lastShown: Shown?

    /// What the last draw read beyond its input (#1901).
    private var drawnEnvironment: BarDrawEnvironment?

    public init() {
        configureRoot()
    }

    public var isVisible: Bool { lastShown != nil && !root.isHidden }

    /// The slot this section last drew into (AX coordinates) — the
    /// one the shelf places it at.
    var shownStrip: CGRect? { lastShown?.strip }

    /// Renders `items` into `strip` in AX coordinates.
    func show(
        items: [Item],
        frontApp: SpaceBarItemView.App? = nil,
        strip: CGRect,
        style: SpaceBarLook,
        stateMarkColors: StateMarkColors
    ) {
        guard !items.isEmpty,
            strip.width >= 1, strip.height >= 1
        else {
            hide()
            return
        }
        let next = Shown(
            items: items,
            frontApp: frontApp,
            strip: strip,
            style: style,
            stateMarkColors: stateMarkColors
        )
        // An identical show draws nothing (#1901): the switch,
        // its focus report and its activation each refresh.
        let environment = BarDrawEnvironment.current
        if isVisible, lastShown == next, drawnEnvironment == environment {
            WorkMeter.shared.add(\.barShowsSkipped)
            return
        }
        // One that moves no frame — a focus change — redraws its
        // content alone (#2086).
        if isVisible, drawnEnvironment == environment,
            let last = lastShown, let front = frontPlacement,
            keepsGeometry(last, next)
        {
            lastShown = next
            WorkMeter.shared.add(\.barContentRedraws)
            redrawContent(since: last, at: front)
            return
        }
        drawnEnvironment = environment
        // A slot that moved or resized hands the motion to the
        // shelf's glide, so the chips land (#1838).
        let slotChanged = lastShown.map { $0.strip != strip } ?? false
        // The segment joins or leaves a SHOWN bar with motion; the
        // first show after a hide lands it (#1903).
        let frontMoves =
            isVisible
            && (lastShown?.frontApp == nil) != (frontApp == nil)
        lastShown = next
        let active = items.first(where: \.active)?.space
        render(
            followingActive: follow.follows(active),
            slotChanged: slotChanged,
            frontMoves: frontMoves
        )
    }

    /// Hides the section, tearing nothing down: its views stay
    /// for the shelf, which draws a leaving section until its leave
    /// lands and shows the root again meanwhile; a hide of a hidden
    /// section writes nothing (#1838).
    public func hide() {
        guard lastShown != nil else { return }
        // A chip hidden under the pointer ends its hold (#1528),
        // though its Space may draw on another display's bar.
        itemViews.forEach { $0.setPointerInside(false) }
        follow.reset()
        shownExpanded = nil
        shownIdentities = []
        lastShown = nil
        hitStrip = .zero
        hitFrames = []
        scrollOffset = 0
        scrollGeom = nil
        scrollRun = nil
        frontPlacement = nil
        frontLeaving = false
        cancelDragAutoScroll()
        root.isHidden = true
        onRendered()
    }

    /// Content run start for given alignment (#293 QA, #385).
    nonisolated static func contentStart(
        total: CGFloat,
        axis: CGFloat,
        alignment: KiwiShelf.Alignment,
        pad: CGFloat
    ) -> CGFloat {
        switch alignment {
        case .start: return pad
        case .center: return max((axis - total) / 2, pad)
        case .end: return max(axis - total - pad, pad)
        }
    }
}

/// Compared by `show` to skip an identical draw (#1901).
extension SpaceBarOverlay.Item: Equatable {}
