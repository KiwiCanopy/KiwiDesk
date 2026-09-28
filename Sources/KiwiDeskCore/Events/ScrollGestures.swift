import Foundation

/// The resolved scroll-gesture settings (#1656 ruling: a global
/// base plus a per-profile override, resolved before they get
/// here). A consumer missing from `chords`, or given an empty
/// chord, is off: a plain scroll always belongs to the window.
public struct ScrollGestureSettings: Equatable, Sendable {
    public private(set) var chords: [ScrollGestures.Consumer: ScrollChord]
    /// KiwiDesk's own Natural scrolling, independent of macOS's.
    public var naturalScrolling: Bool

    public init(
        chords: [ScrollGestures.Consumer: ScrollChord] = [:],
        naturalScrolling: Bool = true
    ) {
        self.chords = chords.filter { !$0.value.isEmpty }
        self.naturalScrolling = naturalScrolling
    }
}

/// The main-actor front of the scroll-gesture tap (#1656, #1519).
/// Two jobs, two doors: `setHandler` wires a consumer once, and
/// `configure` takes the resolved settings on every apply. The one
/// machine tap exists only while a wired consumer has a chord and
/// the core is started — so a user with both gestures off has no
/// tap.
///
/// Chords are keyed by CONSUMER, never the other way round: a
/// profile switch can hand the two gestures each other's chords,
/// and one `configure` lands both.
@MainActor
public final class ScrollGestures {
    /// The two gestures, in the precedence a shared chord takes.
    public enum Consumer: CaseIterable, Hashable, Sendable {
        /// Pans a Scrolling row, or steps a Monocle stack (#1656).
        case pan
        /// Steps between the Spaces of a screen (#1519).
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

    public private(set) var settings = ScrollGestureSettings()
    private var handlers: [Consumer: Handler] = [:]
    /// The consumer each chord's in-flight gesture began with, and
    /// its last event, so a change mid-gesture never hands one
    /// consumer a gesture another began.
    private var inFlight: [ScrollChord: (Consumer, ScrollGestureEvent)] =
        [:]
    private var tap: ScrollTapHandle?
    private var started = false

    public init() {}

    /// Whether the machine tap is live.
    public var isTapped: Bool { tap != nil }

    /// Wires `consumer`'s handler; once, at bootstrap.
    public func setHandler(
        _ consumer: Consumer,
        _ handler: @escaping Handler
    ) {
        handlers[consumer] = handler
        sync()
    }

    /// Applies resolved settings. A consumer whose chord changed has
    /// its gesture in flight ended; an unchanged chord keeps it.
    public func configure(_ settings: ScrollGestureSettings) {
        for consumer in Consumer.allCases
        where settings.chords[consumer] != self.settings.chords[consumer] {
            endInFlight(of: consumer)
        }
        self.settings = settings
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

    /// Hands routed events to the consumer that owns the gesture,
    /// with Natural scrolling applied — here, once, for both.
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
                let handler = handlers[consumer]
            else { continue }
            inFlight[event.chord] =
                event.kind == .ended ? nil : (consumer, event)
            if !settings.naturalScrolling {
                event.delta.dx = -event.delta.dx
                event.delta.dy = -event.delta.dy
            }
            handler(event)
        }
    }

    /// The wired consumers' chords, the set the tap consumes.
    private var liveChords: Set<ScrollChord> {
        Set(
            Consumer.allCases.compactMap { consumer in
                handlers[consumer].flatMap { _ in
                    settings.chords[consumer]
                }
            }
        )
    }

    /// The consumer a chord reaches: the first wired one in
    /// `Consumer` order, so a shared chord is never a coin flip.
    private func owner(of chord: ScrollChord) -> Consumer? {
        Consumer.allCases.first {
            handlers[$0] != nil && settings.chords[$0] == chord
        }
    }

    private func endInFlight(of consumer: Consumer) {
        guard
            let (chord, (_, last)) = inFlight.first(where: {
                $0.value.0 == consumer
            })
        else { return }
        inFlight[chord] = nil
        var ended = last
        ended.kind = .ended
        ended.delta = .zero
        ended.momentum = false
        handlers[consumer]?(ended)
    }

    private func sync() {
        let chords = liveChords
        guard started, !chords.isEmpty else {
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
