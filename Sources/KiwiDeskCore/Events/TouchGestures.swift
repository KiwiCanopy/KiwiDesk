import Foundation

/// The main-actor front of the touch reader (#1873). One door,
/// `resolve`, takes the resolve's inputs; the reader runs only
/// while the core is started AND a bound slot reads touches, so a
/// user with every touch slot unbound has no reader (ruling ▸
/// Reader: no binding, no reader).
@MainActor
public final class TouchGestures {
    public typealias Handler =
        @MainActor (
            TrackpadGestureSlot,
            TrackpadGestureBinding,
            TrackpadGestureEvent
        ) -> Void
    typealias MakeReader =
        @MainActor (@escaping TouchReader.Deliver) -> TouchReaderHandle?

    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Builds the machine reader. Live in production; both
    /// `makeTestCore` twins pin one that touches nothing.
    var makeReader: MakeReader = { TouchReader.live(deliver: $0) }
    /// What macOS answers itself, read at each start.
    var readSystemGestures: @MainActor () -> TrackpadSystemGestures = {
        TrackpadSystemGestures.readLive()
    }

    /// The seeds until the first resolve, as on a fresh install.
    public private(set) var bindings = TrackpadGestureSeeds.resolved(
        base: TrackpadGestureMap(),
        profile: nil
    )
    /// The inputs `KiwiCore.applyTrackpadGestures` resolves from,
    /// written through `resolve` alone.
    private(set) var base = TrackpadGestureMap()
    private(set) var profileOverride: TrackpadGestureMap?
    private(set) var system = TrackpadSystemGestures.unread
    private var handler: Handler?
    private var reader: TouchReaderHandle?
    private var started = false

    public init() {}

    /// Whether the machine reader is live.
    public var isReading: Bool { reader != nil }

    /// Wires the one handler; once, at bootstrap.
    func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
        sync()
    }

    /// The one write of the resolve's inputs and output.
    func resolve(
        base: TrackpadGestureMap,
        profileOverride: TrackpadGestureMap?
    ) {
        self.base = base
        self.profileOverride = profileOverride
        bindings = TrackpadGestureSeeds.resolved(
            base: base,
            profile: profileOverride
        )
        sync()
    }

    /// A config load's reset: the load configures at its tail.
    func resetInputs() {
        base = TrackpadGestureMap()
        profileOverride = nil
    }

    func start() {
        started = true
        system = readSystemGestures()
        sync()
    }

    func stop() {
        started = false
        sync()
    }

    /// Hands each recognized gesture to the handler, once its slot
    /// is bound with exactly the modifiers held and macOS does not
    /// answer the gesture itself.
    func receive(_ events: [TrackpadGestureEvent]) {
        guard started, let handler else { return }
        for event in events {
            guard let slot = Self.slot(of: event),
                let binding = bindings[slot],
                binding.modifiers == event.modifiers,
                !system.owns(event)
            else { continue }
            handler(slot, binding, event)
        }
    }

    static func slot(of event: TrackpadGestureEvent) -> TrackpadGestureSlot? {
        switch event.kind {
        case .tap: return .tap(fingers: event.fingers)
        case .swipe: return .swipe(fingers: event.fingers)
        }
    }

    /// Whether a bound slot needs the touch reader.
    private var needsReader: Bool {
        handler != nil
            && bindings.keys.contains { $0.source == .touches }
    }

    private func sync() {
        guard started, needsReader else {
            reader?.stop()
            reader = nil
            return
        }
        guard reader == nil else { return }
        reader = makeReader { [weak self] events in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.receive(events) }
            }
        }
        onLog(
            reader == nil
                ? "touch reader: unavailable (no MultitouchSupport "
                    + "or no trackpad)"
                : "touch reader: started"
        )
    }
}
