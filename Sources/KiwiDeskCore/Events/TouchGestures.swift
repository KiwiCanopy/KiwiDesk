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
    /// What macOS answers itself, read afresh for each batch of
    /// recognized gestures, which are rare, so a change in System
    /// Settings ▸ Trackpad lands at the next gesture.
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
    private var handler: Handler?
    private var reader: TouchReaderHandle?
    /// The last reader verdict logged, so a Mac with no trackpad
    /// says so once rather than at every resolve.
    private var loggedReading: Bool?
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
        sync()
    }

    func stop() {
        started = false
        sync()
    }

    /// Builds the reader again over the devices connected now —
    /// the session's return from sleep or a lock, after which a
    /// Bluetooth trackpad comes back as a device nobody registered.
    func rearm() {
        reader?.stop()
        reader = nil
        sync()
    }

    /// Hands each recognized gesture to the handler, once its slot
    /// is bound with exactly the modifiers held and macOS does not
    /// answer the gesture itself.
    func receive(_ events: [TrackpadGestureEvent]) {
        guard started, let handler else { return }
        let system = readSystemGestures()
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
        case .gesture(let slot):
            return slot.source == .gestureEvents ? slot : nil
        }
    }

    /// The chords the gesture-event consumer swallows, per slot —
    /// the one door #2447's tap takes them through, handed on every
    /// change and empty while stopped, so no binding arms no mask.
    /// Its gestures come back through `receive`.
    var onGestureEventChords:
        (@MainActor ([TrackpadGestureSlot: ScrollChord]) -> Void)?
    {
        didSet { sync() }
    }

    private var gestureEventChords: [TrackpadGestureSlot: ScrollChord] {
        guard started else { return [:] }
        return bindings.filter { $0.key.source == .gestureEvents }
            .mapValues(\.modifiers)
    }

    /// Whether a bound slot needs the touch reader.
    private var needsReader: Bool {
        handler != nil
            && bindings.keys.contains { $0.source == .touches }
    }

    private func sync() {
        onGestureEventChords?(gestureEventChords)
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
        let reading = reader != nil
        guard reading != loggedReading else { return }
        loggedReading = reading
        onLog(
            reading
                ? "touch reader: started"
                : "touch reader: unavailable (no MultitouchSupport "
                    + "or no trackpad)"
        )
    }
}
