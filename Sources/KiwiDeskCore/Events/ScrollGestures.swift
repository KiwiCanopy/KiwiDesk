import Foundation

/// The main-actor front of the scroll-gesture tap (#1656, #1519):
/// each consumer binds the chord it answers to, and the one
/// machine tap exists only while something is bound and the core
/// is started — so a user with both gestures off has no tap.
///
/// Bindings are keyed by CONSUMER, never by chord: a profile
/// switch can hand the two gestures each other's chords, and
/// either rebind order must land both.
@MainActor
public final class ScrollGestures {
    /// The two gestures, in the precedence a shared chord takes.
    public enum Consumer: CaseIterable, Sendable {
        /// ⌃⌥ + scroll pans a Scrolling row (#1656).
        case pan
        /// ⌃⌥⌘ + scroll steps between Spaces (#1519).
        case step
    }

    public typealias Handler = @MainActor (ScrollGestureEvent) -> Void
    typealias MakeTap =
        @MainActor (@escaping ScrollGestureTap.Deliver)
        -> ScrollTapHandle?

    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Builds the machine tap. Live in production; `makeTestCore`
    /// pins one that touches nothing.
    var makeTap: MakeTap = { ScrollGestureTap.live(deliver: $0) }

    /// KiwiDesk's own Natural scrolling (#1656 ruling), applied
    /// here once for both gestures: off flips every delta.
    public var naturalScrolling = true

    private var bindings: [Consumer: (ScrollChord, Handler)] = [:]
    /// The consumer each chord's in-flight gesture began with, and
    /// its last event, so a rebind mid-gesture never hands one
    /// consumer a gesture another began.
    private var inFlight: [ScrollChord: (Consumer, ScrollGestureEvent)] =
        [:]
    private var tap: ScrollTapHandle?
    private var started = false

    public init() {}

    /// Whether the machine tap is live.
    public var isTapped: Bool { tap != nil }

    /// Binds `consumer` to `chord`, or unbinds it with nil or an
    /// empty chord — a plain scroll always belongs to the window.
    /// A changed chord ends the consumer's gesture in flight; the
    /// same chord only replaces the handler, so a re-apply of an
    /// unchanged binding never cuts a live gesture.
    public func bind(
        _ consumer: Consumer,
        to chord: ScrollChord?,
        _ handler: @escaping Handler
    ) {
        if let chord, bindings[consumer]?.0 == chord {
            bindings[consumer] = (chord, handler)
            return
        }
        endInFlight(of: consumer)
        if let chord, !chord.isEmpty {
            bindings[consumer] = (chord, handler)
        } else {
            bindings[consumer] = nil
        }
        sync()
    }

    /// Called once the Accessibility grant is in hand.
    func start() {
        started = true
        sync()
    }

    /// Ends every gesture in flight first: what the tap still had
    /// queued is dropped with it.
    func stop() {
        Consumer.allCases.forEach(endInFlight(of:))
        inFlight = [:]
        started = false
        sync()
    }

    /// Hands routed events to the consumer that owns the gesture.
    func receive(_ events: [ScrollGestureEvent]) {
        // Events queued before a stop are dropped with the tap.
        guard started else { return }
        for var event in events {
            if event.kind == .began {
                guard let consumer = owner(of: event.chord) else {
                    continue
                }
                inFlight[event.chord] = (consumer, event)
            }
            guard let (consumer, _) = inFlight[event.chord],
                let (_, handler) = bindings[consumer]
            else { continue }
            inFlight[event.chord] =
                event.kind == .ended ? nil : (consumer, event)
            if !naturalScrolling {
                event.delta.dx = -event.delta.dx
                event.delta.dy = -event.delta.dy
            }
            handler(event)
        }
    }

    /// The consumer a chord reaches: the first in `Consumer`
    /// order, so a shared chord is never a coin flip.
    private func owner(of chord: ScrollChord) -> Consumer? {
        Consumer.allCases.first { bindings[$0]?.0 == chord }
    }

    private func endInFlight(of consumer: Consumer) {
        guard
            let (chord, (_, last)) = inFlight.first(where: {
                $0.value.0 == consumer
            }),
            let (_, handler) = bindings[consumer]
        else { return }
        inFlight[chord] = nil
        var ended = last
        ended.kind = .ended
        ended.delta = .zero
        ended.momentum = false
        handler(ended)
    }

    private func sync() {
        guard started, !bindings.isEmpty else {
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
        tap?.setChords(Set(bindings.values.map(\.0)))
    }
}
