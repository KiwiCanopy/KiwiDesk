import AppKit

/// What a hiding bar draws while hidden (#761): Space dots for the
/// Space Bar, a short line for the App Bar — one mark per bar, two
/// on an edge both bars hide on.
struct ShelfIndicatorSpec: Equatable {
    enum Mark: Equatable {
        /// One per Space on the screen, in bar order.
        case dots([Dot])
        /// The App Bar's: no window dots, so the App Bar has one
        /// hidden look.
        case line
    }

    struct Dot: Equatable {
        /// The Space the screen shows: drawn wide.
        let current: Bool
        /// A Space holding windows: drawn brighter.
        let occupied: Bool
        /// An end dot with Spaces beyond it (`ShelfDotWindow`):
        /// drawn small, as iOS page dots are.
        var small = false
    }

    let mark: Mark
    /// The indicator's frame, AX coordinates.
    let frame: CGRect
    let horizontal: Bool
    let fill: String
    /// The bar's own state inks (`SpaceBarItemView.stateColor`):
    /// the current Space's, an idle one's, an empty one's.
    let currentInk: String
    let ink: String
    let emptyInk: String
    /// The bars' indicator colour, the hover's border.
    let highlight: String
    /// Whether its bar is shown over it: the indicator then
    /// draws nothing but stays for VoiceOver, its value "shown".
    let shown: Bool
    /// The pointer rests in the band, the reveal delay running:
    /// the plate grows and takes the highlight's border.
    let hovered: Bool
    /// How its shelf reveals, which the mark's fade keeps time with.
    var reveal: BarMotion.RevealKind = .slide
    /// The hover rim's width: the bars' indicator weight, capped
    /// at the plate's growth so the dots keep their room.
    var rimWidth: CGFloat = hoverGrowth
    /// The bars' indicator sheen (`BorderSheen`); 0 draws flat.
    var sheen: CGFloat = 0
    /// Its bar is hidden while a sibling on its edge shows: the
    /// mouse opens one bar at a time, so the mark gives way as
    /// under its own bar, VoiceOver still reading it hidden.
    var yields = false

    /// The current Space's name, drawn in its dot while the mark
    /// is hovered (`label`, `ShelfIndicatorSpec+Label`).
    var label: Label?
    /// Where the current Space sits, for VoiceOver: its place
    /// from 1 and the Space count, which the dots may not all show.
    var position: Position?

    /// Whether the mark draws nothing: its bar or a sibling shows.
    var standsAside: Bool { shown || yields }

    /// A dot's ink, by the bar's own ladder: current, then held
    /// windows, then empty.
    func ink(of dot: Dot) -> String {
        if dot.current { return currentInk }
        return dot.occupied ? ink : emptyInk
    }

    /// The indicator's depth across its edge (pt).
    static let depth = KiwiShelf.hiddenDepth
    static let dot: CGFloat = 4
    static let smallDot: CGFloat = 2
    static let currentDot: CGFloat = 12
    static let dotGap: CGFloat = 4
    static let pad: CGFloat = 4
    /// How far a hovered plate grows on each side — the room the
    /// panel keeps around it. Six points take the 8 pt plate to
    /// 20, deep enough for the Space's name to read in the 0.35 s
    /// before the bar opens (device feedback, #761).
    static let hoverGrowth: CGFloat = 6

    /// The hover rim's width for `shelf`: its indicator weight
    /// (bars.md ▸ an indicator's weight), at most the growth.
    static func rimWidth(for shelf: KiwiShelf) -> CGFloat {
        min(shelf.resolvedHighlightWidth, hoverGrowth)
    }
    static let lineLength: CGFloat = 36
    /// Its distance from the shelf's screen side, inside the band.
    static let inset: CGFloat = 0

    /// The indicator's length along its edge.
    static func length(of mark: Mark) -> CGFloat {
        switch mark {
        case .line:
            return lineLength
        case .dots(let dots):
            let marks = dots.reduce(0) {
                $0 + ($1.current ? currentDot : $1.small ? smallDot : dot)
            }
            let gaps = CGFloat(max(0, dots.count - 1)) * dotGap
            return marks + gaps + 2 * pad
        }
    }

    /// Where the indicator sits on `strip` (AX, y down): centred
    /// on `centre` — an offset along `edge` from the strip's start,
    /// its band's middle — else on the strip, against its screen
    /// side.
    static func frame(
        of mark: Mark,
        in strip: CGRect,
        edge: AppBarEdge,
        centre: CGFloat? = nil
    ) -> CGRect {
        let horizontal = edge.isHorizontal
        let along = min(
            length(of: mark),
            horizontal ? strip.width : strip.height
        )
        let midX = centre.map { strip.minX + $0 } ?? strip.midX
        let midY = centre.map { strip.minY + $0 } ?? strip.midY
        switch edge {
        case .top:
            return CGRect(
                x: midX - along / 2,
                y: strip.minY + inset,
                width: along,
                height: depth
            )
        case .bottom:
            return CGRect(
                x: midX - along / 2,
                y: strip.maxY - inset - depth,
                width: along,
                height: depth
            )
        case .left:
            return CGRect(
                x: strip.minX + inset,
                y: midY - along / 2,
                width: depth,
                height: along
            )
        case .right:
            return CGRect(
                x: strip.maxX - inset - depth,
                y: midY - along / 2,
                width: depth,
                height: along
            )
        }
    }
}

/// One hiding shelf's indicator panel (#761). It ignores the mouse
/// — the hover band is judged from the pointer, and a click on it
/// pins nothing — so the windows below it keep their clicks.
@MainActor
final class ShelfIndicator {
    let view = ShelfIndicatorView()
    private(set) var panel: NSPanel?
    #if DEBUG
        /// Set by `ShelfIndicators.ordersIndicatorPanels` (#1894).
        var ordersPanel = true
    #endif

    isolated deinit {
        panel?.orderOut(nil)
    }

    func show(_ spec: ShelfIndicatorSpec) {
        // A shown indicator asked again for what it draws moves
        // nothing (#1901).
        if panel?.isVisible == true, view.spec == spec { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // Room around the mark for its hover growth and its
        // label, taken once: the plate grows inside it and a hover
        // never resizes the panel.
        let room = Self.room(of: spec)
        let frame = spec.frame.insetBy(dx: -room.width, dy: -room.height)
        panel.setFrame(
            GeometryUtils.flip(
                frame,
                primaryHeight: GeometryUtils.primaryHeight
            ),
            display: false
        )
        view.frame = CGRect(origin: .zero, size: frame.size)
        view.render(spec, animated: panel.isVisible)
        #if DEBUG
            guard ordersPanel else { return }
        #endif
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// The room the panel keeps around `spec`'s mark on each side:
    /// the hover's growth, and along the edge half its label's.
    static func room(of spec: ShelfIndicatorSpec) -> CGSize {
        let growth = ShelfIndicatorSpec.hoverGrowth
        let along = growth + spec.labelExtra / 2
        return spec.horizontal
            ? CGSize(width: along, height: growth)
            : CGSize(width: growth, height: along)
    }

    /// The mark's resting frame inside a view `bounds` sized by
    /// `room(of:)`.
    static func mark(
        of spec: ShelfIndicatorSpec,
        in bounds: CGRect
    ) -> CGRect {
        let room = room(of: spec)
        return bounds.insetBy(dx: room.width, dy: room.height)
    }

    var isVisible: Bool { panel?.isVisible == true }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.ignoresMouseEvents = true
        panel.contentView = view
        return panel
    }
}

/// Every hiding bar's indicator, keyed like its reveal.
@MainActor
final class ShelfIndicators {
    typealias Key = ShelfRevealer.Key

    private var indicators: [Key: ShelfIndicator] = [:]
    /// Each Space mark's first dot shown last pass
    /// (`ShelfDotWindow`), handed to the next; kept only beside a
    /// mark still drawn.
    var dotStarts: [Key: Int] = [:]
    /// The indicator's press: the show/hide action on its bar.
    var onPress: @MainActor (Key) -> Void = { _ in }
    #if DEBUG
        /// Off in both `makeTestCore` twins (#1894).
        var ordersIndicatorPanels = true
    #endif

    /// Shows `specs`, dropping every indicator absent from them.
    func sync(_ specs: [Key: ShelfIndicatorSpec]) {
        for key in indicators.keys where specs[key] == nil {
            indicators.removeValue(forKey: key)?.hide()
        }
        dotStarts = dotStarts.filter { specs[$0.key] != nil }
        for (key, spec) in specs {
            let indicator = indicators[key] ?? ShelfIndicator()
            indicators[key] = indicator
            #if DEBUG
                indicator.ordersPanel = ordersIndicatorPanels
            #endif
            indicator.view.carriesSpaceBar = key.bar == .space
            indicator.view.onPress = { [weak self] in self?.onPress(key) }
            indicator.show(spec)
        }
    }

    #if DEBUG
        func indicatorForTesting(_ key: Key) -> ShelfIndicator? {
            indicators[key]
        }
    #endif
}
