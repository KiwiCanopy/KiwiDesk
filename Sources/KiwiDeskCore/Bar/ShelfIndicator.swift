import AppKit

/// What a hiding shelf draws while hidden (#761): Space dots where
/// it carries the Space Bar, alone or fused, else a short line.
struct ShelfIndicatorSpec: Equatable {
    enum Mark: Equatable {
        /// One per Space on the screen, in bar order.
        case dots([Dot])
        /// A lone App Bar's: no window dots, so the App Bar has
        /// one hidden look.
        case line
    }

    struct Dot: Equatable {
        /// The Space the screen shows: drawn wide.
        let current: Bool
        /// A Space holding windows: drawn brighter.
        let occupied: Bool
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
    /// Whether the shelf is shown over it: the indicator then
    /// draws nothing but stays for VoiceOver, its value "shown".
    let shown: Bool
    /// The pointer rests in the band, the reveal delay running:
    /// the plate grows and takes the highlight's border.
    let hovered: Bool
    /// Whether its shelf draws a plate, which morphs out of the
    /// mark; a Boxed shelf cross-fades with it instead.
    var morphs = true
    /// The hover rim's width: the bars' indicator weight, capped
    /// at the plate's growth so the dots keep their room.
    var rimWidth: CGFloat = hoverGrowth
    /// The bars' indicator sheen (`BorderSheen`); 0 draws flat.
    var sheen: CGFloat = 0

    /// A dot's ink, by the bar's own ladder: current, then held
    /// windows, then empty.
    func ink(of dot: Dot) -> String {
        if dot.current { return currentInk }
        return dot.occupied ? ink : emptyInk
    }

    /// The indicator's depth across its edge (pt).
    static let depth = KiwiShelf.hiddenDepth
    static let dot: CGFloat = 4
    static let currentDot: CGFloat = 12
    static let dotGap: CGFloat = 4
    static let pad: CGFloat = 4
    /// How far a hovered plate grows on each side — the room the
    /// panel keeps around it. Three points take the 8 pt plate to
    /// 14, so the growth reads (device feedback, #761).
    static let hoverGrowth: CGFloat = 3

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
                $0 + ($1.current ? currentDot : dot)
            }
            let gaps = CGFloat(max(0, dots.count - 1)) * dotGap
            return marks + gaps + 2 * pad
        }
    }

    /// Where the indicator sits on `strip` (AX, y down): centred
    /// along `edge`, against its screen side.
    static func frame(
        of mark: Mark,
        in strip: CGRect,
        edge: AppBarEdge
    ) -> CGRect {
        let along = min(
            length(of: mark),
            edge.isHorizontal ? strip.width : strip.height
        )
        switch edge {
        case .top:
            return CGRect(
                x: strip.midX - along / 2,
                y: strip.minY + inset,
                width: along,
                height: depth
            )
        case .bottom:
            return CGRect(
                x: strip.midX - along / 2,
                y: strip.maxY - inset - depth,
                width: along,
                height: depth
            )
        case .left:
            return CGRect(
                x: strip.minX + inset,
                y: strip.midY - along / 2,
                width: depth,
                height: along
            )
        case .right:
            return CGRect(
                x: strip.maxX - inset - depth,
                y: strip.midY - along / 2,
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
        // Room around the mark for its hover growth, taken once:
        // the plate grows inside it and the panel never resizes.
        let room = ShelfIndicatorSpec.hoverGrowth
        let frame = spec.frame.insetBy(dx: -room, dy: -room)
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

    var isVisible: Bool { panel?.isVisible == true }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.ignoresMouseEvents = true
        panel.contentView = view
        return panel
    }
}

/// Every hiding shelf's indicator, keyed like its shelf.
@MainActor
final class ShelfIndicators {
    typealias Key = ShelfManager.Key

    private var indicators: [Key: ShelfIndicator] = [:]
    /// The indicator's press: the show/hide action on its shelf.
    var onPress: @MainActor (Key) -> Void = { _ in }
    #if DEBUG
        /// Off in both `makeTestCore` twins (#1894).
        var ordersIndicatorPanels = true
    #endif

    /// Shows `specs`, dropping every indicator absent from them.
    func sync(_ specs: [Key: (spec: ShelfIndicatorSpec, space: Bool)]) {
        for key in indicators.keys where specs[key] == nil {
            indicators.removeValue(forKey: key)?.hide()
        }
        for (key, entry) in specs {
            let indicator = indicators[key] ?? ShelfIndicator()
            indicators[key] = indicator
            #if DEBUG
                indicator.ordersPanel = ordersIndicatorPanels
            #endif
            indicator.view.carriesSpaceBar = entry.space
            indicator.view.onPress = { [weak self] in self?.onPress(key) }
            indicator.show(entry.spec)
        }
    }

    #if DEBUG
        func indicatorForTesting(_ key: Key) -> ShelfIndicator? {
            indicators[key]
        }
    #endif
}
