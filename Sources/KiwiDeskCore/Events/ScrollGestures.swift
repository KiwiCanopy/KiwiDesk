import CoreGraphics
import Foundation

/// What one held chord does with a scroll (#3199): a phased swipe's
/// binding, a vertical wheel's and a sideways wheel's. A chord with
/// none of the three is not in the tap's set.
public struct ScrollRoute: Equatable, Sendable {
    public var swipe: GestureAction?
    public var wheel: GestureAction?
    public var wheelX: GestureAction?

    public init(
        swipe: GestureAction? = nil,
        wheel: GestureAction? = nil,
        wheelX: GestureAction? = nil
    ) {
        self.swipe = swipe
        self.wheel = wheel
        self.wheelX = wheelX
    }

    var isEmpty: Bool { swipe == nil && wheel == nil && wheelX == nil }

    /// The binding a scroll reaches: a phased one the swipe's, a
    /// wheel burst's by the axis the router owned it on.
    func action(for event: ScrollGestureEvent) -> GestureAction? {
        switch event.input {
        case .trackpad: swipe
        case .wheel: event.sideways ? wheelX : wheel
        }
    }
}

/// The resolved scroll-gesture settings (#1656, #3199): the routes
/// the gesture bindings resolved to and the per-input Natural
/// scrolling, resolved before they get here. A plain scroll always
/// belongs to the window: an empty chord never routes.
public struct ScrollGestureSettings: Equatable, Sendable {
    public private(set) var routes: [ScrollChord: ScrollRoute]
    /// KiwiDesk's own Natural scrolling per input.
    public let naturalTrackpad: Bool
    public let naturalMouse: Bool

    public init(
        routes: [ScrollChord: ScrollRoute] = [:],
        naturalTrackpad: Bool = true,
        naturalMouse: Bool = true
    ) {
        self.routes = routes.filter { !$0.key.isEmpty && !$0.value.isEmpty }
        self.naturalTrackpad = naturalTrackpad
        self.naturalMouse = naturalMouse
    }

    /// The chords the tap consumes, per input.
    var tapChords: ScrollTapChords {
        let routes = self.routes
        return ScrollTapChords(
            swipe: Set(routes.filter { $0.value.swipe != nil }.keys),
            wheel: Set(routes.filter { $0.value.wheel != nil }.keys),
            wheelX: Set(routes.filter { $0.value.wheelX != nil }.keys)
        )
    }

    /// Whether `input`'s scrolls keep the natural direction.
    func isNatural(_ input: ScrollGestureEvent.Input) -> Bool {
        input == .wheel ? naturalMouse : naturalTrackpad
    }
}

/// The main-actor front of the scroll-gesture tap (#1656, #1519,
/// #3199). Two jobs, two doors: `setHandler` wires the one consumer
/// once, and `configure` takes the resolved settings on every
/// apply. The machine tap exists only while a chord routes and the
/// core is started.
@MainActor
public final class ScrollGestures {
    public typealias Handler =
        @MainActor (ScrollGestureEvent, ScrollRoute) -> Void
    typealias MakeTap =
        @MainActor (@escaping ScrollGestureTap.Deliver)
        -> ScrollTapHandle?

    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Builds the machine tap. Live in production; `makeTestCore`
    /// pins one that touches nothing.
    var makeTap: MakeTap = { ScrollGestureTap.live(deliver: $0) }
    /// macOS's own Natural scrolling (#3200). Live in production;
    /// `makeTestCore` pins it unset.
    var host = HostNaturalScrolling.live
    /// The cached host value a `.system` input follows: read at the
    /// first start and on each change notice, never per event.
    private(set) var hostNatural = true
    private var followingHost = false
    /// Re-runs the resolve; wired once at bootstrap.
    var onHostChange: @MainActor () -> Void = {}

    public private(set) var settings = ScrollGestureSettings()
    /// The inputs `KiwiCore.applyScrollGestures` resolves from: the
    /// base a config load or a verb wrote, and the live profile's
    /// override — written through `adoptResolution` alone.
    private(set) var base = ScrollGestureBase.defaults
    private(set) var profileOverride: ScrollGestureOverride?
    /// The two resolved: what a consumer reads for its stepping.
    private(set) var resolved = ScrollGestureBase.defaults
    private var handler: Handler?
    /// Each chord's gesture in flight: the route it began with and
    /// its last event, so a change mid-gesture never hands a
    /// gesture to a binding it did not begin with.
    private var inFlight: [ScrollChord: (ScrollRoute, ScrollGestureEvent)] =
        [:]
    private var tap: ScrollTapHandle?
    private var started = false

    public init() {}

    /// Whether the machine tap is live.
    public var isTapped: Bool { tap != nil }

    /// Wires the consumer; once, at bootstrap.
    public func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
        sync()
    }

    /// Applies resolved settings. A chord whose route changed has
    /// its gesture in flight ended; an unchanged route keeps it.
    public func configure(_ settings: ScrollGestureSettings) {
        for chord in Array(inFlight.keys)
        where settings.routes[chord] != inFlight[chord]?.0 {
            endInFlight(of: chord)
        }
        self.settings = settings
        sync()
    }

    /// The one write of the resolve's inputs and output, ending in
    /// the tap's `configure` — `KiwiCore.applyScrollGestures`'s door
    /// (#1656, `ScrollGestureConfigureSeamTests`).
    func adoptResolution(
        base: ScrollGestureBase,
        profileOverride: ScrollGestureOverride?,
        resolved: ScrollGestureBase,
        routes: [ScrollChord: ScrollRoute]
    ) {
        self.base = base
        self.profileOverride = profileOverride
        self.resolved = resolved
        configure(
            resolved.tapSettings(routes: routes, hostNatural: hostNatural)
        )
    }

    /// Follows macOS's Natural scrolling from the first start on:
    /// reads it, watches its change notice, and calls
    /// `onHostChange` whenever the cached value moves.
    func followHost() {
        guard !followingHost else { return }
        followingHost = true
        let first = host.read() ?? true
        host.watch { [weak self] in
            guard let self else { return }
            let now = host.read() ?? true
            guard now != hostNatural else { return }
            hostNatural = now
            onHostChange()
        }
        guard first != hostNatural else { return }
        hostNatural = first
        onHostChange()
    }

    /// A config load's reset: the inputs return to the defaults
    /// WITHOUT configuring — the load configures at its tail.
    func resetInputs() {
        base = .defaults
        profileOverride = nil
    }

    /// Called once the Accessibility grant is in hand.
    func start() {
        started = true
        followHost()
        sync()
    }

    /// Ends every gesture in flight first: what the tap still had
    /// queued is dropped with it.
    func stop() {
        Array(inFlight.keys).forEach(endInFlight(of:))
        inFlight = [:]
        started = false
        sync()
    }

    /// Hands routed events to the consumer with the route the
    /// gesture began with, Natural scrolling applied — here, once.
    func receive(_ events: [ScrollGestureEvent]) {
        // Events queued before a stop are dropped with the tap.
        guard started, let handler else { return }
        for var event in events {
            if event.kind == .began {
                guard let route = settings.routes[event.chord] else {
                    continue
                }
                inFlight[event.chord] = (route, event)
            }
            guard let (route, _) = inFlight[event.chord] else { continue }
            inFlight[event.chord] =
                event.kind == .ended ? nil : (route, event)
            if !settings.isNatural(event.input) {
                event.delta.dx = -event.delta.dx
                event.delta.dy = -event.delta.dy
                event.reversed = true
            }
            handler(event, route)
        }
    }

    private func endInFlight(of chord: ScrollChord) {
        guard let (route, last) = inFlight[chord] else { return }
        inFlight[chord] = nil
        var ended = last
        ended.kind = .ended
        ended.delta = .zero
        ended.momentum = false
        handler?(ended, route)
    }

    private func sync() {
        let chords = settings.tapChords
        guard started, handler != nil, !chords.isEmpty else {
            tap?.stop()
            tap = nil
            return
        }
        if tap == nil {
            tap = makeTap { [weak self] events in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.receive(events) }
                }
            }
            onLog(
                tap == nil
                    ? "scroll tap: refused by macOS (Accessibility?)"
                    : "scroll tap: installed"
            )
        }
        tap?.setChords(chords)
    }
}
