import AppKit

/// What an `auto` bar leaves at its edge (#761, #3349): its handle,
/// a thin strip along the bar's whole run that reserves nothing and
/// floats. The pointer's approach thickens it and its contents peek
/// through — the Space dots, or the App Bar's glyphs — and only the
/// open bar takes a click.
struct ShelfHandleSpec: Equatable {
    /// What peeks through the thickened handle.
    enum Peek: Equatable {
        /// One per Space on the screen, in bar order.
        case dots([Dot])
        /// The App Bar's glyphs, in bar order.
        case glyphs([NSImage])
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

    /// Where the current Space sits, for VoiceOver: its place from
    /// 1 and the Space count, which the dots may not all show.
    struct Position: Equatable {
        let index: Int
        let count: Int
    }

    /// How a grow reveal's origin exceeds the handle's thickening;
    /// the handle grows by none, a reveal mark's default.
    struct Growth: Equatable, Sendable {
        var widen: CGFloat = 0
        var across: CGFloat = 0

        static let none = Growth()
    }

    let peek: Peek
    /// The handle at rest, AX coordinates: its bar's run, `depth`
    /// deep, `inset` in from the screen side of the shelf's area.
    let frame: CGRect
    /// The edge its shelf hides on.
    let edge: AppBarEdge
    /// The shelf's Fill, the thickened plate's (#2569).
    let fill: GlassFill
    /// The bar's own state inks (`SpaceBarItemView.stateColor`):
    /// the current Space's, an idle one's, an empty one's, which
    /// the peeking dots take.
    let currentInk: String
    let ink: String
    let emptyInk: String
    /// Whether its bar is shown over it: the handle then draws
    /// nothing but stays for VoiceOver, its value "shown".
    let shown: Bool
    /// The pointer is in the approach: the handle thickens and its
    /// contents peek through.
    let hovered: Bool
    /// How its shelf reveals, which the handle's fade keeps time
    /// with.
    let reveal: BarMotion.RevealKind
    /// Its bar is hidden while a sibling on its edge shows: the
    /// mouse opens one bar at a time, so the handle gives way as
    /// under its own bar, VoiceOver still reading it hidden.
    var yields = false
    var position: Position?
    /// The thickened plate draws as tinted glass, as its bar does
    /// (`LiquidGlassGate.rendered`, #2567).
    var glass = false
    /// The resting handle's colour (`kiwishelf.handle_color`,
    /// #3357): empty is Automatic.
    var restHex = ""

    var horizontal: Bool { edge.isHorizontal }

    /// Whether the handle draws nothing: its bar or a sibling shows.
    var standsAside: Bool { shown || yields }

    /// A dot's ink, by the bar's own ladder: current, then held
    /// windows, then empty.
    func ink(of dot: Dot) -> String {
        if dot.current { return currentInk }
        return dot.occupied ? ink : emptyInk
    }

    /// The handle's depth at rest (pt): a hairline that reads
    /// without nagging (ui-designer preview, #3349).
    static let depth: CGFloat = 3
    /// How far the thickened plate grows on each side — the room
    /// the panel keeps around it: 3 pt to 9 pt across, held to the
    /// screen side (`BarMotion.hoverPlate`).
    static let hoverGrowth: CGFloat = 3
    /// Its distance from the screen side of the shelf's area.
    static let inset: CGFloat = 2
    /// The handle at rest takes the system's label ink at this
    /// alpha (ui-designer preview, 35–40%).
    static let restAlpha: CGFloat = 0.38
    /// The handle's ink at rest (#3357): `hex` as set, or on
    /// Automatic the label ink at `restAlpha`, resolved in the
    /// current drawing appearance.
    static func restColor(hex: String) -> NSColor {
        .mark(
            hex: hex,
            fallback: .labelColor.withAlphaComponent(restAlpha)
        )
    }
    /// What peeks through takes this alpha.
    static let peekAlpha: CGFloat = 0.7
    static let dot: CGFloat = 4
    static let smallDot: CGFloat = 2
    static let currentDot: CGFloat = 12
    static let dotGap: CGFloat = 4
    /// The App Bar's glyphs peeking through: their tops, clipped.
    static let glyph: CGFloat = 12
    static let glyphGap: CGFloat = 6

    /// The handle at rest along `run` (AX, y down): `run`'s extent
    /// along `edge`, `depth` deep, `inset` in from `side` — the
    /// screen side of the shelf's area, on the edge's axis.
    static func frame(
        along run: CGRect,
        edge: AppBarEdge,
        side: CGFloat
    ) -> CGRect {
        switch edge {
        case .top:
            return CGRect(
                x: run.minX,
                y: side + inset,
                width: run.width,
                height: depth
            )
        case .bottom:
            return CGRect(
                x: run.minX,
                y: side - inset - depth,
                width: run.width,
                height: depth
            )
        case .left:
            return CGRect(
                x: side + inset,
                y: run.minY,
                width: depth,
                height: run.height
            )
        case .right:
            return CGRect(
                x: side - inset - depth,
                y: run.minY,
                width: depth,
                height: run.height
            )
        }
    }

    /// The thickened plate (AX): what the panel's room holds.
    var grown: CGRect {
        BarMotion.hoverPlate(mark: frame, edge: edge, hovered: true)
    }
}

/// One hiding bar's handle panel (#761). It ignores the mouse —
/// the approach is judged from the pointer, and a click on it pins
/// nothing — so the windows below it keep their clicks, a bottom
/// scrollbar or status bar under the strip included (#3349 rule 6).
@MainActor
final class ShelfHandle {
    let view = ShelfHandleView()
    private(set) var panel: NSPanel?
    #if DEBUG
        /// Set by `ShelfHandles.ordersHandlePanels` (#1894).
        var ordersPanel = true
    #endif

    isolated deinit {
        panel?.orderOut(nil)
    }

    func show(_ spec: ShelfHandleSpec) {
        // A shown handle asked again for what it draws moves
        // nothing (#1901).
        if panel?.isVisible == true, view.spec == spec { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        // Room for the thickened plate, taken once: the plate grows
        // inside it and an approach never resizes the panel.
        let frame = Self.room(of: spec)
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

    /// The panel's frame for `spec`, AX coordinates: its
    /// thickened plate, which never crosses the screen side.
    static func room(of spec: ShelfHandleSpec) -> CGRect {
        spec.grown
    }

    /// The handle's resting frame inside a view `bounds` sized by
    /// `room(of:)`.
    static func mark(
        of spec: ShelfHandleSpec,
        in bounds: CGRect
    ) -> CGRect {
        let room = room(of: spec)
        return spec.frame.offsetBy(
            dx: bounds.minX - room.minX,
            dy: bounds.minY - room.minY
        )
    }

    var isVisible: Bool { panel?.isVisible == true }

    private func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        panel.ignoresMouseEvents = true
        panel.contentView = view
        return panel
    }
}

/// Every hiding bar's handle, keyed like its reveal.
@MainActor
final class ShelfHandles {
    typealias Key = ShelfRevealer.Key

    private var handles: [Key: ShelfHandle] = [:]
    /// Each Space mark's first dot shown last pass
    /// (`ShelfDotWindow`), handed to the next; kept only beside a
    /// mark still drawn.
    var dotStarts: [Key: Int] = [:]
    /// The handle's press: the show/hide action on its bar.
    var onPress: @MainActor (Key) -> Void = { _ in }
    #if DEBUG
        /// Off in both `makeTestCore` twins (#1894).
        var ordersHandlePanels = true
    #endif

    /// Shows `specs`, dropping every handle absent from them.
    func sync(_ specs: [Key: ShelfHandleSpec]) {
        for key in handles.keys where specs[key] == nil {
            handles.removeValue(forKey: key)?.hide()
        }
        dotStarts = dotStarts.filter { specs[$0.key] != nil }
        for (key, spec) in specs {
            let handle = handles[key] ?? ShelfHandle()
            handles[key] = handle
            #if DEBUG
                handle.ordersPanel = ordersHandlePanels
            #endif
            handle.view.carriesSpaceBar = key.bar == .space
            handle.view.onPress = { [weak self] in self?.onPress(key) }
            handle.show(spec)
        }
    }

    #if DEBUG
        func handleForTesting(_ key: Key) -> ShelfHandle? {
            handles[key]
        }
    #endif
}
