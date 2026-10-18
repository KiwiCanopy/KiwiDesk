import AppKit

/// One shelf on one edge of a display (#1517, #1731): the ONE
/// panel its sections draw on — both while the bars share the
/// edge, one while they are split — the ONE plate beneath them,
/// solid or Liquid Glass with its tint, and the divider between
/// them. The sections render
/// into their own views (`SpaceBarOverlay.root`,
/// `AppBarOverlay.root`); this places them and owns the surface
/// they share, so there is one fill and no seam.
@MainActor
final class ShelfOverlay {
    /// A section to place: its view, its slot on the shelf in AX
    /// coordinates, and — in the view's own coordinates — the
    /// plate its run asks for and the span its run draws (#1779).
    struct Section {
        let view: NSView
        let slot: CGRect
        let plate: CGRect
        /// Zero falls back to the slot, so every site states it.
        let content: CGRect
    }

    /// The last input laid out.
    private var drawn: Drawn?

    private(set) var panel: NSPanel?
    #if DEBUG
        /// Set by `ShelfManager.ordersPanels` (#1894).
        var ordersPanel = true
    #endif

    /// AppKit keeps a visible panel alive after its owner is gone,
    /// so a dropped overlay would leave it on screen (#1868).
    isolated deinit {
        panel?.orderOut(nil)
    }

    /// The fade-out in flight, if any (#1838): its landing orders
    /// the panel out unless a show cleared it meanwhile.
    var leaving: UUID?
    /// A hiding shelf (#761): it slides in on appearing and out
    /// on leaving, set by `ShelfManager` before each show.
    var slides = false
    /// Whether the leave in flight is a slide.
    var leavingSlides = false
    /// The reveal in flight, whose landing alone ends its motion.
    var revealing: UUID?
    /// A hiding shelf's mark in the content's coordinates, which a
    /// reveal grows out of (#761); set by `ShelfManager`.
    var revealOrigin: CGRect?
    /// Lands a reveal or a retract after its length — the reveal's
    /// own timer; a test hands a queue it drains by hand.
    var afterReveal: (TimeInterval, @escaping @MainActor () -> Void) -> Void =
        {
            BarMotion.afterReveal($0, $1)
        }
    /// Fires once the shelf has left the screen — at once, or when
    /// its fade-out lands; `ShelfManager` retires it there.
    var onLeft: @MainActor () -> Void = {}
    /// A press on the panel, with the view it hit and its type
    /// (`ShelfPanel`).
    var onPress: @MainActor (NSView?, NSEvent.EventType) -> Void = {
        _,
        _ in
    }
    /// Whether a fade-out is in flight.
    var isLeaving: Bool { leaving != nil }
    /// Schedules a landing once the plate glide has run — the
    /// glide's own timer; a test hands a queue it drains by hand.
    var afterGlide: (@escaping @MainActor () -> Void) -> Void = {
        BarMotion.afterGroupGlide($0)
    }
    /// Sections shrinking out after they left, each stamped by its
    /// latest leave, whose landing alone removes it (#1838).
    var leavingViews: [NSView: UUID] = [:]
    /// Each section's drawn content at its last placement, in its
    /// own coordinates — where a glide starts it from (#1838).
    var placedContent: [ObjectIdentifier: CGRect] = [:]
    let content = BarMenuView()
    /// Holds both sections and the divider, above the plate.
    let stripView = BarMenuView()
    var solidPlate: NSView?
    var glassPlate: NSView?
    var glassTint: GlassBackdrop?
    /// The glass plate's box move; a test swaps it to see whether
    /// a pass asked it to travel.
    var moveFrame: BarFrameMove = BarMotion.setFrame(_:to:animated:)
    /// The plate's border (#1679), above whichever plate draws
    /// and below the strip; hidden with the plates.
    let plateBorder = ShelfBorder.make()
    /// The glass shows through behind the sections rather than
    /// hosting them, so nothing is ever reparented into it.
    let glassFiller = NSView()
    let divider = NSView()
    /// The divider's grip, live only while the shelf is full.
    let handle = ShelfDividerHandle()
    /// Whether the grip is hovered or dragged, and the shelf the
    /// divider was last painted for.
    var dividerHovered = false
    var dividerShelf: KiwiShelf?
    /// The bars' context menus (#1518): the plate outside both
    /// runs answers as empty bar space, and the grip, which finds
    /// them by walking up, as the divider.
    weak var contextMenus: BarContextMenus? {
        didSet {
            content.contextMenus = contextMenus
            stripView.contextMenus = contextMenus
        }
    }

    var isVisible: Bool { panel?.isVisible == true }

    /// Lays the shelf out over `strip` (AX coordinates) on `edge`
    /// with `shelf` as rendered — glass already gated by
    /// `LiquidGlassGate` — and shows it, fading in where it appears
    /// (#1838); `sheen` paints the plate's border with the ramp
    /// (#1644).
    func show(
        strip: CGRect,
        edge: AppBarEdge,
        shelf: KiwiShelf,
        sheen: CGFloat,
        sections: [Section],
        divider range: ShelfArrangement.Divider? = nil
    ) {
        guard !sections.isEmpty, strip.width >= 1, strip.height >= 1
        else {
            hide(animated: true)
            return
        }
        let next = Drawn(
            strip: strip,
            edge: edge,
            shelf: shelf,
            sheen: sheen,
            sections: sections,
            divider: range,
            primaryHeight: GeometryUtils.primaryHeight,
            environment: .current
        )
        // A shown, settled shelf asked again for what it already
        // lays out moves nothing (#1901).
        if panel?.isVisible == true, leaving == nil, drawn == next {
            WorkMeter.shared.add(\.shelfShowsSkipped)
            return
        }
        drawn = next
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // A shelf appearing fades in where it lands; one already on
        // screen glides to its new placement (#1517), and one fading
        // out fades back (#1838).
        let glides = panel.isVisible
        let fadesBack = glides && leaving != nil
        let slidesBack = fadesBack && leavingSlides
        leaving = nil
        stripView.frame = CGRect(origin: .zero, size: strip.size)
        let horizontal = edge.isHorizontal
        let depth = horizontal ? strip.height : strip.width
        let plate = Self.plateFrame(
            sections: sections,
            strip: strip,
            horizontal: horizontal,
            shelf: shelf
        )
        let radius = shelf.resolvedCornerRadius(forThickness: depth)
        let travels = BarMotion.shelfGlideLength > 0
        if glides, travels {
            standGlideStarts(sections, in: strip, horizontal: horizontal)
        }
        BarMotion.runPlateGlide {
            place(
                sections,
                in: strip,
                horizontal: horizontal,
                animated: glides
            )
            layoutPlate(
                plate,
                edge: edge,
                shelf: shelf,
                sheen: sheen,
                radius: radius,
                animated: glides
            )
            layoutDivider(
                sections: sections,
                strip: strip,
                shelf: shelf,
                horizontal: horizontal,
                animated: glides
            )
            if fadesBack, !slidesBack {
                BarMotion.setAlpha(content, to: 1, animated: true)
            }
        }
        if slidesBack { revealIn() }
        layoutHandle(
            range: range,
            divider: Self.dividerFrame(
                slots: sections.map(\.slot),
                contents: sections.map(\.content),
                strip: strip,
                horizontal: horizontal
            ),
            horizontal: horizontal
        )
        panel.setFrame(
            GeometryUtils.flip(
                strip,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: true
        )
        if !panel.isVisible {
            #if DEBUG
                guard ordersPanel else { return }
            #endif
            if slides {
                panel.orderFrontRegardless()
                revealIn()
                return
            }
            guard travels else {
                panel.orderFrontRegardless()
                return
            }
            // Shown transparent and committed so, laid out already,
            // so the fade starts from it (#1838).
            BarMotion.standCommitted {
                content.alphaValue = 0
                panel.orderFrontRegardless()
            }
            BarMotion.runPlateGlide {
                BarMotion.setAlpha(content, to: 1, animated: true)
            }
        }
    }

    /// Orders the shelf out — after fading out where `animated`
    /// and the glide has a length (#1838), the sections its
    /// managers hid drawing on until it lands — and fires `onLeft`
    /// once it has left. Returns whether this call began the
    /// leave; false where a fade is already running, which keeps
    /// its own landing.
    @discardableResult
    func hide(animated: Bool = false) -> Bool {
        guard let panel, panel.isVisible else {
            leaving = nil
            onLeft()
            return true
        }
        if animated, slides { return retractOut() }
        guard animated, BarMotion.shelfGlideLength > 0 else {
            leaving = nil
            panel.orderOut(nil)
            content.alphaValue = 1
            onLeft()
            return true
        }
        // A fade already running keeps its landing: every bar
        // refresh inside the glide asked again, and a restarted
        // fade never landed on a lively Space (device, #1838).
        guard leaving == nil else { return false }
        for view in stripView.subviews
        where view !== divider && view !== handle {
            view.isHidden = false
        }
        let token = UUID()
        leaving = token
        BarMotion.runPlateGlide {
            BarMotion.setAlpha(content, to: 0, animated: true)
        }
        afterGlide { [weak self] in
            guard let self, self.leaving == token else { return }
            self.leaving = nil
            self.panel?.orderOut(nil)
            self.content.alphaValue = 1
            self.onLeft()
        }
        return true
    }

    /// Lays the grip over the divider line while the shelf is
    /// full (`range`); otherwise the line is plain, with no hover.
    /// Placed at the line's TARGET frame — the line itself may be
    /// mid-glide, reporting where it was.
    private func layoutHandle(
        range: ShelfArrangement.Divider?,
        divider target: CGRect?,
        horizontal: Bool
    ) {
        handle.range = range
        handle.horizontal = horizontal
        guard range != nil, let target else {
            handle.isHidden = true
            handle.setHovered(false)
            return
        }
        handle.isHidden = false
        handle.frame = Self.handleFrame(
            divider: target,
            depth: horizontal
                ? stripView.bounds.height : stripView.bounds.width,
            horizontal: horizontal
        )
    }
}
