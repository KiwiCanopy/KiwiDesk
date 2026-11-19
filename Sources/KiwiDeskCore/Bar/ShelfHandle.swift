import AppKit

/// What an `auto` bar leaves at its edge (#761, #3349): its handle,
/// a thin two-tone line along the bar's whole run, flush on the
/// edge, that reserves nothing and floats (#3361). An approach runs
/// a fill along it from the point nearest the pointer, and the bar
/// opens as the fill completes (#3360); only the open bar takes a
/// click.
struct ShelfHandleSpec: Equatable {
    /// Where the current Space sits, for VoiceOver: its place from
    /// 1 and the Space count.
    struct Position: Equatable {
        let index: Int
        let count: Int
    }

    /// How a grow reveal's origin exceeds the handle; the handle
    /// grows by none, a reveal mark's default.
    struct Growth: Equatable, Sendable {
        var widen: CGFloat = 0
        var across: CGFloat = 0

        static let none = Growth()
    }

    /// An approach's fill (#3360 ruling 7): it starts at `origin`,
    /// the share of the run from its leading end (AX: left or top)
    /// nearest the pointer as it entered, and both its ends reach
    /// the run's ends together at `until`, as the bar opens. Both
    /// stamps come from the revealer's clock at the event that set
    /// them — `started` the entry, or the rest on the handle that
    /// hurried it — so the view runs it for their difference and
    /// reads no clock.
    struct Fill: Equatable {
        var origin: CGFloat
        var started: Date
        var until: Date

        /// How long it runs from `started`.
        var length: TimeInterval { until.timeIntervalSince(started) }
    }

    /// The handle at rest, AX coordinates: its bar's run, `depth`
    /// deep, flush on the screen side of the shelf's area.
    let frame: CGRect
    /// The edge its shelf hides on.
    let edge: AppBarEdge
    /// Whether its bar is shown over it: the handle then draws
    /// nothing but stays for VoiceOver, its value "shown".
    let shown: Bool
    /// How its shelf reveals, which the handle's fade keeps time
    /// with.
    let reveal: BarMotion.RevealKind
    /// The approach's fill running along the handle, nil at rest.
    var fill: Fill?
    /// Its bar is hidden while a sibling on its edge shows by hover
    /// (#3512): the mouse opens one bar at a time, so the handle
    /// gives way as under its own bar, VoiceOver still reading it
    /// hidden.
    var yields = false
    var position: Position?
    /// The resting handle's colour (`kiwishelf.handle_color`,
    /// #3357): empty is Automatic.
    var restHex = ""

    var horizontal: Bool { edge.isHorizontal }

    /// Whether the handle draws nothing: its bar shows, or it
    /// yields.
    var standsAside: Bool { shown || yields }

    /// The handle's depth on `shelf` (pt), `kiwishelf.handle_thickness`
    /// (#3451): `parts(of:)` insets the core a `hairline` of the
    /// opposite tone from it (#3361 ruling 1, #3366).
    static func depth(of shelf: KiwiShelf) -> CGFloat {
        shelf.resolvedHandleThickness
    }
    static let hairline: CGFloat = 0.5
    /// The hairline's strength, constant through a fill (#3514).
    static let hairlineStrength: CGFloat = 0.2
    /// How far a grow reveal's origin grows past the handle on each
    /// side (`BarMotion.hoverPlate`).
    static let hoverGrowth: CGFloat = 3
    /// How deep the pointer rests "on" the handle, from the edge
    /// (#3360): its hover band, a value of its own.
    static let hoverDepth: CGFloat = 9
    /// Its distance from the screen side of the shelf's area: flush
    /// (#3361 ruling 2, kept by #3366).
    static let inset: CGFloat = 0
    /// How far the resting core mixes toward its hairline's tone
    /// (#3514): the fill is the ink itself, so the step from rest
    /// to fill is one of lightness and reads alike on any ground.
    static let restMix: CGFloat = 0.45
    /// The handle's ink (#3357): Automatic the label ink, else the
    /// picked colour, at its own alpha — never forced opaque, with
    /// no floor (#1857); resolved in the drawing appearance.
    static func ink(hex: String) -> NSColor {
        guard !hex.isEmpty else {
            return NSColor(name: nil) { labelInk(in: $0) }
        }
        return NSColor(kiwiHex: hex)
    }
    /// The label ink as `appearance` draws it, its own alpha kept.
    static func labelInk(in appearance: NSAppearance) -> NSColor {
        resolved(.labelColor, in: appearance)
    }
    /// `color` as `appearance` draws it, in sRGB.
    static func resolved(
        _ color: NSColor,
        in appearance: NSAppearance
    ) -> NSColor {
        var out = color
        appearance.performAsCurrentDrawingAppearance {
            out = color.usingColorSpace(.sRGB) ?? color
        }
        return out
    }
    /// Whether `color` reads light: the one pivot the hairline's
    /// tone and the resting mix take (#3361, #3514).
    static func isLight(_ color: NSColor) -> Bool {
        0.2126 * color.redComponent + 0.7152 * color.greenComponent
            + 0.0722 * color.blueComponent > 0.5
    }
    /// The ink at rest (#3514): the ink mixed `restMix` toward its
    /// hairline's tone — darker beside a light ink, lighter beside
    /// a dark one — at the ink's own alpha.
    static func restColor(hex: String) -> NSColor {
        let full = ink(hex: hex)
        return NSColor(name: nil) { appearance in
            let base = resolved(full, in: appearance)
            let tone: CGFloat = isLight(base) ? 0 : 1
            let mix = { (c: CGFloat) in c + (tone - c) * restMix }
            return NSColor(
                srgbRed: mix(base.redComponent),
                green: mix(base.greenComponent),
                blue: mix(base.blueComponent),
                alpha: base.alphaComponent
            )
        }
    }
    /// The ink the progress fill takes: the ink itself (#3514).
    static func fillColor(hex: String) -> NSColor {
        ink(hex: hex)
    }
    /// The hairline (#3361 ruling 1): neutral, the opposite tone of
    /// the core's ink — white beside a dark ink, black beside a
    /// light one — never the user's colour; resolved in the current
    /// drawing appearance.
    static func hairlineColor(hex: String) -> NSColor {
        let ink = NSColor(cgColor: ink(hex: hex).cgColor)?
            .usingColorSpace(.sRGB)
        return (ink.map(isLight) == true ? NSColor.black : NSColor.white)
            .withAlphaComponent(hairlineStrength)
    }

    /// The two capsules in `bounds`, a handle's frame or the
    /// pocket's tab (#3366): the outer one in the hairline ink, and
    /// the core inset `hairline` on top of it, so the hairline wraps
    /// the ends too. Each is rounded by half its thickness.
    static func parts(of bounds: CGRect) -> (outer: CGRect, core: CGRect) {
        (bounds, bounds.insetBy(dx: hairline, dy: hairline))
    }

    /// A capsule's corner radius: half its thickness.
    static func radius(of capsule: CGRect) -> CGFloat {
        min(capsule.width, capsule.height) / 2
    }

    /// The colour a handle and the pocket's tab ink with,
    /// `kiwishelf.handle_color` (#3357): empty is Automatic — the one
    /// read both make, so a pick reaches both.
    static func restHex(of shelf: KiwiShelf) -> String {
        shelf.handleColor
    }

    /// The handle along `run` (AX, y down): `run`'s extent along
    /// `edge`, `depth` deep, `inset` in from `side` — the screen
    /// side of the shelf's area, on the edge's axis.
    static func frame(
        along run: CGRect,
        edge: AppBarEdge,
        side: CGFloat,
        depth: CGFloat
    ) -> CGRect {
        band(along: run, edge: edge, side: side, past: inset, deep: depth)
    }

    /// A band along `run`, `deep` in from `side` past `inset`.
    private static func band(
        along run: CGRect,
        edge: AppBarEdge,
        side: CGFloat,
        past inset: CGFloat,
        deep: CGFloat
    ) -> CGRect {
        switch edge {
        case .top:
            return CGRect(
                x: run.minX,
                y: side + inset,
                width: run.width,
                height: deep
            )
        case .bottom:
            return CGRect(
                x: run.minX,
                y: side - inset - deep,
                width: run.width,
                height: deep
            )
        case .left:
            return CGRect(
                x: side + inset,
                y: run.minY,
                width: deep,
                height: run.height
            )
        case .right:
            return CGRect(
                x: side - inset - deep,
                y: run.minY,
                width: deep,
                height: run.height
            )
        }
    }

    /// The hover band (AX): along the handle, `hoverDepth` in from
    /// the screen side itself, the inset included, so the pointer at
    /// the edge rests on it. Resting there runs the fill over
    /// `ShelfReveal.revealDelay` (#3360 ruling 2).
    var hoverBand: CGRect {
        let side: CGFloat
        switch edge {
        case .top: side = frame.minY - Self.inset
        case .bottom: side = frame.maxY + Self.inset
        case .left: side = frame.minX - Self.inset
        case .right: side = frame.maxX + Self.inset
        }
        return Self.band(
            along: frame,
            edge: edge,
            side: side,
            past: 0,
            deep: Self.hoverDepth
        )
    }
}

/// One hiding bar's handle panel (#761). It ignores the mouse —
/// the approach is judged from the pointer, and a click on it pins
/// nothing — so the windows below it keep their clicks, a bottom
/// scrollbar or status bar under the handle included (#3349 rule 6).
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
        // The handle's own frame: a fill runs inside it and an
        // approach never resizes the panel.
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

    /// The panel's frame for `spec`, AX coordinates: the handle,
    /// which never crosses the screen side.
    static func room(of spec: ShelfHandleSpec) -> CGRect {
        spec.frame
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
