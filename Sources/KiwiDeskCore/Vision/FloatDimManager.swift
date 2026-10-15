import AppKit

/// KiwiVision's per-float panels (#2103 ruling 3): a float the
/// float tier lifts above the focused window sits above the plate,
/// so each one wears the plate's veil on a panel of its own,
/// stacked above the float's own chrome so its mark and its ring
/// dim with it (owner ruling, option A, 2026-10-15).
@MainActor
final class FloatDimManager {
    /// One float to veil.
    struct Float: Equatable {
        let id: WindowID
        /// The float's frame, AX coordinates.
        let frame: CGRect
        /// How far the veil reaches past the frame: the float's
        /// ring, so it dims with the float.
        let outset: CGFloat
        /// The veil's corner radius, ring reach included.
        let cornerRadius: CGFloat
        /// The window the veil orders directly above: the float's
        /// mark panel where it has one, else the float. Chrome
        /// orders directly above its float, so it always lands
        /// under a veil already above it.
        let anchor: CGWindowID
        /// Whether the float is carried across Desktops (#2149).
        let spans: Bool
    }

    /// What `sync` draws.
    struct Request {
        var floats: [Float]
        /// Whether KiwiVision is on: a change fades, a focus move
        /// does not.
        var on: Bool
        var dim: CGFloat
        var blur: Bool
        /// Whether a WindowServer stream reports the floats
        /// restacking (`BorderManager.ordersOverlay`).
        var tracked: Bool
    }

    private struct Entry {
        let backend: any FloatDimBackend
        var float: Float?
        /// Where the veil sits now, AX coordinates, unoutset.
        var frame: CGRect?
        /// The anchor the veil was last ordered above, nil while
        /// it owes an order.
        var ordered: CGWindowID?
        var spans = false
    }

    /// True while our own animation drives a window (#594).
    var isAnimating: @MainActor (WindowID) -> Bool = { _ in false }
    /// The engine's just-issued instant frame (#881).
    var commandedFrame: @MainActor (WindowID) -> CGRect? = { _ in nil }
    /// Whether the WindowServer stream delivers a float's events.
    var isWindowServerTracked: @MainActor (WindowID) -> Bool = {
        _ in false
    }
    /// The Reduce Motion read the fades name (borders.md).
    var reduceMotion: @MainActor () -> Bool = { BarMotion.isReduced }
    #if DEBUG
        /// Test-only: builds panel backends. Every test core sets
        /// it to the inert panel.
        var panelFactory: (() -> any FloatDimBackend)?
    #endif

    private var entries: [WindowID: Entry] = [:]
    private var wasOn = false
    private var dim: CGFloat = 0
    private var blur = false

    init() {}

    /// The floats whose veil shows.
    var shown: Set<WindowID> {
        Set(entries.filter { $0.value.float != nil }.keys)
    }

    /// The floats whose veil is dormant: kept in the WindowServer
    /// request so a focus move leaves it unchanged (#1925).
    var dormant: Set<WindowID> {
        Set(entries.filter { $0.value.float == nil }.keys)
    }

    /// Whether any veil is shown or fading.
    var hasShown: Bool {
        entries.values.contains { $0.backend.isShown }
    }

    /// Draws `request`; a veil whose float is no longer `alive`
    /// goes, one whose float left the request goes dormant.
    func sync(_ request: Request, alive: Set<WindowID>, reassert: Bool) {
        let fades = request.on != wasOn
        wasOn = request.on
        dim = request.dim
        blur = request.blur
        let motion = fades ? reduceMotion() : true
        let wanted = Dictionary(
            request.floats.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for (id, entry) in entries where !alive.contains(id) {
            entry.backend.orderOut()
            entries[id] = nil
        }
        for (id, entry) in entries where wanted[id] == nil {
            entry.backend.hide(reduceMotion: motion)
            entries[id]?.float = nil
        }
        for float in request.floats {
            var entry =
                entries[float.id]
                ?? Entry(backend: makeBackend())
            let woke = entry.float == nil
            entry.float = float
            entry.frame = FollowSource.syncFrame(
                spec: float.frame,
                held: entry.frame,
                animating: isAnimating(float.id),
                commanded: commandedFrame(float.id)
            )
            draw(entry)
            if entry.spans != float.spans {
                // A panel dropping the flag stays on every
                // Desktop until it is ordered again (#2149).
                entry.backend.setSpansDesktops(float.spans)
                if !float.spans { entry.backend.orderOut() }
                entry.spans = float.spans
                entry.ordered = nil
            }
            if BorderManager.ordersOverlay(
                reassert: reassert,
                needsOrder: woke || entry.ordered != float.anchor,
                tracked: request.tracked
            ) {
                entry.backend.order(above: float.anchor)
                entry.ordered = float.anchor
            }
            entry.backend.show(reduceMotion: motion)
            entries[float.id] = entry
        }
    }

    /// A reported frame for `id` — a tick or an AX echo — through
    /// the one `FollowSource` decision the ring and mark take.
    func follow(
        _ id: WindowID,
        windowFrame: CGRect,
        source: FollowSource,
        pin: SizePin?
    ) {
        guard var entry = entries[id], entry.float != nil,
            let frame = source.renderFrame(
                reported: windowFrame,
                pin: pin,
                wsTracked: isWindowServerTracked(id),
                animating: isAnimating(id)
            )
        else { return }
        entry.frame = frame
        entries[id] = entry
        draw(entry)
    }

    /// The float's WindowServer bounds, read by the watch.
    func reposition(_ id: WindowID, windowFrame: CGRect) {
        guard var entry = entries[id], entry.float != nil else { return }
        entry.frame = windowFrame
        entries[id] = entry
        draw(entry)
    }

    /// The float's reorder event, after its mark and ring have
    /// re-ordered: the veil goes back above them.
    func restack(_ id: WindowID) {
        guard let float = entries[id]?.float else { return }
        entries[id]?.backend.order(above: float.anchor)
        entries[id]?.ordered = float.anchor
    }

    /// The float was hidden — minimized, its app hidden, its
    /// Desktop left: the veil goes with it until it returns.
    func hideWindow(_ id: WindowID) {
        guard entries[id] != nil else { return }
        entries[id]?.backend.orderOut()
        entries[id]?.ordered = nil
    }

    /// Drops every veil at once.
    func clear() {
        for entry in entries.values { entry.backend.orderOut() }
        entries = [:]
        wasOn = false
    }

    private func draw(_ entry: Entry) {
        guard let float = entry.float, let frame = entry.frame
        else { return }
        entry.backend.update(
            frame: frame.insetBy(dx: -float.outset, dy: -float.outset),
            cornerRadius: float.cornerRadius,
            dim: dim,
            blur: blur
        )
    }

    private func makeBackend() -> any FloatDimBackend {
        #if DEBUG
            if let panelFactory { return panelFactory() }
        #endif
        return AppKitFloatDimPanel()
    }
}
