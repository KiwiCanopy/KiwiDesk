import Foundation

/// The main-actor front of the touch reader (#1873, #3199). One
/// door, `resolve`, takes the resolved gesture bindings; the reader
/// runs only while the core is started AND a bound key reads
/// touches, so a user with every touch gesture unbound has no
/// reader (ruling ▸ Reader: no binding, no reader).
@MainActor
public final class TouchGestures {
    public typealias Handler =
        @MainActor (GestureKey, GestureAction, TrackpadGestureEvent)
        -> Void
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

    /// The touch inputs' bindings; the seeds' until the first
    /// resolve, as on a fresh install.
    public private(set) var bindings = TouchGestures.touchBindings(
        GestureSeeds.resolved(base: GestureMap(), profile: nil)
    )
    /// Whether a swipe keeps its direction: the trackpad's Natural
    /// scrolling, the one flip a swipe takes (#3200 amendment).
    private(set) var natural = true
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
    /// The one door: `KiwiCore.applyScrollGestures`'s, with the
    /// resolved bindings and the trackpad's Natural scrolling.
    func resolve(
        _ resolved: [GestureKey: GestureAction],
        natural: Bool
    ) {
        bindings = Self.touchBindings(resolved)
        self.natural = natural
        sync()
    }

    /// The bindings the touch reader or a gesture event fires.
    static func touchBindings(
        _ resolved: [GestureKey: GestureAction]
    ) -> [GestureKey: GestureAction] {
        resolved.filter { key, _ in
            key.input.device == .trackpad && key.input != .swipe2
        }
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
        for var event in events {
            guard let input = Self.input(of: event),
                let action = bindings[GestureKey(input, event.modifiers)],
                !system.owns(event)
            else { continue }
            // Natural scrolling off reverses a family's swipe, the one
            // flip; a direction table's arm keeps the fingers' way.
            if !natural, case .family = action,
                case .swipe(let direction) = event.kind
            {
                event.kind = .swipe(direction.opposite)
            }
            handler(GestureKey(input, event.modifiers), action, event)
        }
    }

    /// The input a recognized gesture is: a tap or a swipe by its
    /// fingers, a gesture event by its slot.
    static func input(of event: TrackpadGestureEvent) -> GestureInput? {
        switch event.kind {
        case .tap: return .tap(fingers: event.fingers)
        case .swipe: return .swipe(fingers: event.fingers)
        case .gesture(let input):
            return input.isGestureEvent ? input : nil
        }
    }

    /// The chords the gesture-event consumer swallows, per input —
    /// the one door #2447's tap takes them through, handed on every
    /// change and empty while stopped, so no binding arms no mask.
    /// Its gestures come back through `receive`.
    var onGestureEventChords:
        (@MainActor ([GestureInput: Set<ScrollChord>]) -> Void)?
    {
        didSet { sync() }
    }

    private var gestureEventChords: [GestureInput: Set<ScrollChord>] {
        guard started else { return [:] }
        var out: [GestureInput: Set<ScrollChord>] = [:]
        for key in bindings.keys where key.input.isGestureEvent {
            out[key.input, default: []].insert(key.keys)
        }
        return out
    }

    /// Whether a bound slot needs the touch reader: one the touch
    /// router fires.
    private var needsReader: Bool {
        handler != nil
            && bindings.keys.contains {
                $0.input.fingers != nil && $0.input.isFired
            }
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
