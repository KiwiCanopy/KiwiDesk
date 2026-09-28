import Foundation

/// The main-actor front of the scroll-gesture tap (#1656, #1519):
/// consumers bind a chord, and the one machine tap exists only
/// while something is bound and the core is started — so a user
/// with both gestures off has no tap at all.
@MainActor
public final class ScrollGestures {
    public typealias Handler = @MainActor (ScrollGestureEvent) -> Void
    typealias MakeTap =
        @MainActor (@escaping ScrollGestureTap.Deliver)
        -> ScrollTapHandle?

    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Builds the machine tap. Live in production; `makeTestCore`
    /// pins one that touches nothing.
    var makeTap: MakeTap = { ScrollGestureTap.live(deliver: $0) }

    private var handlers: [ScrollChord: Handler] = [:]
    private var tap: ScrollTapHandle?
    private var started = false

    public init() {}

    /// Whether the machine tap is live.
    public var isTapped: Bool { tap != nil }

    /// Binds `chord`'s scrolls to `handler`, replacing a previous
    /// binding of the same chord. An empty chord is refused: a
    /// plain scroll always belongs to the window.
    public func bind(_ chord: ScrollChord, _ handler: @escaping Handler) {
        guard !chord.isEmpty else { return }
        handlers[chord] = handler
        sync()
    }

    public func unbind(_ chord: ScrollChord) {
        guard handlers.removeValue(forKey: chord) != nil else { return }
        sync()
    }

    /// Called once the Accessibility grant is in hand.
    func start() {
        started = true
        sync()
    }

    func stop() {
        started = false
        sync()
    }

    /// Hands routed events to their chord's consumer.
    func receive(_ events: [ScrollGestureEvent]) {
        for event in events { handlers[event.chord]?(event) }
    }

    private func sync() {
        guard started, !handlers.isEmpty else {
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
        tap?.setChords(Set(handlers.keys))
    }
}
