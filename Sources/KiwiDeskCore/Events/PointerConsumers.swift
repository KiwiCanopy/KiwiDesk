import CoreGraphics
import Foundation

/// The main-actor front of the one pointer tap (#2447, #2764
/// ruling 2026-11-01). Two jobs, two doors: `setHandler` wires a
/// consumer once, and `configure` takes its settings on every
/// apply. The machine tap exists only while a wired consumer is
/// on and the core is started, created over the union of the live
/// consumers' masks and rebuilt when that union changes — so a
/// user with every consumer off has no tap.
@MainActor
public final class PointerConsumers {
    /// The consumers, in the precedence a contested event takes.
    public enum Consumer: CaseIterable, Hashable, Sendable {
        /// The modifier grab: ⌃⌘ + drag moves, ⌃⌥ + drag resizes
        /// (#2447). It owns the button stream it began.
        case grab

        /// The events this consumer needs — its one mask constant.
        /// The grab hears the left-button trio for "+ drag" and
        /// moves with modifier changes for "+ move (no click)".
        public var mask: CGEventMask {
            switch self {
            case .grab: return PointerConsumers.grabMask
            }
        }
    }

    /// The grab's mask: the tccd log showed it asks `PostEvent`
    /// alone at `.cgSessionEventTap`, as the scroll tap's does
    /// (input-and-animation.md, 2026-11-08).
    nonisolated static let grabMask: CGEventMask = [
        CGEventType.leftMouseDown, .leftMouseDragged, .leftMouseUp,
        .mouseMoved, .flagsChanged,
    ].reduce(0) { $0 | CGEventMask(1) << $1.rawValue }

    public typealias GrabHandler = @MainActor (ModifierGrabEvent) -> Void
    typealias MakeTap =
        @MainActor (CGEventMask, @escaping PointerTap.Deliver)
        -> PointerTapHandle?

    var onLog: @MainActor (String) -> Void = CoreLog.write
    /// Builds the machine tap. Live in production; `makeTestCore`
    /// pins one that touches nothing.
    var makeTap: MakeTap = { PointerTap.live(mask: $0, deliver: $1) }

    /// The grab's settings as the tap reads them, sanitised; written
    /// by `KiwiCore.applyGestures` alone, from the drag bindings.
    public private(set) var grabSettings = ModifierDragSettings.defaults
    private var grabHandler: GrabHandler?
    /// The grab the main actor has heard begin and not yet end, as
    /// it began.
    public private(set) var grabInFlight: ModifierGrabEvent?
    private var tap: PointerTapHandle?
    private var tapMask: CGEventMask = 0
    /// Which tap a delivery came from: one an old tap queued before
    /// a stop or a rebuild is dropped, since no router of the new
    /// tap will end what it began.
    private var tapGeneration = 0
    /// The union macOS last refused: asked again only at `start()`
    /// or once a consumer's switch moves the union.
    private var refusedMask: CGEventMask?
    private var started = false

    public init() {}

    /// Whether the machine tap is live.
    public var isTapped: Bool { tap != nil }

    /// Wires the grab's handler; once, at bootstrap.
    public func setGrabHandler(_ handler: @escaping GrabHandler) {
        grabHandler = handler
        sync()
    }

    /// Applies the grab's settings. A grab in flight whose binding
    /// left ends here.
    func configure(grab settings: ModifierDragSettings) {
        let settings = settings.sanitized
        if let grab = grabInFlight,
            !settings.bindings.contains(
                ModifierDragBinding(
                    grab.action,
                    chord: grab.chord,
                    start: grab.start
                )
            )
        {
            endGrab()
        }
        grabSettings = settings
        sync()
    }

    /// Called once the Accessibility grant is in hand.
    func start() {
        started = true
        refusedMask = nil
        sync()
    }

    /// Ends the grab in flight first: what the tap still had
    /// queued is dropped with it.
    func stop() {
        endGrab()
        started = false
        sync()
    }

    /// Hands routed events to their consumer, a batch's moves
    /// coalesced to the last one so a slow main actor writes one
    /// frame per turn.
    func receive(_ delivery: PointerTapDelivery, fromTap generation: Int) {
        guard started, generation == tapGeneration else { return }
        if delivery.reenabled {
            onLog("pointer tap: re-enabled after macOS disabled it")
        }
        let events = delivery.grab.enumerated().filter { index, event in
            event.phase != .moved
                || delivery.grab.dropFirst(index + 1).first?.phase != .moved
        }.map(\.element)
        for event in events {
            switch event.phase {
            case .began: grabInFlight = event
            case .moved: guard grabInFlight != nil else { continue }
            case .ended:
                guard grabInFlight != nil else { continue }
                grabInFlight = nil
            }
            grabHandler?(event)
        }
    }

    #if DEBUG
        /// Test seam: a delivery from the live tap, never read by
        /// production, which always names the tap it came from.
        func receive(_ delivery: PointerTapDelivery) {
            receive(delivery, fromTap: tapGeneration)
        }
    #endif

    /// The live consumers: wired, and on.
    private var liveConsumers: [Consumer] {
        Consumer.allCases.filter { consumer in
            switch consumer {
            case .grab: grabHandler != nil && grabSettings.isOn
            }
        }
    }

    /// Ends the grab in flight for it, with no event of its own.
    private func endGrab() {
        guard var ended = grabInFlight else { return }
        grabInFlight = nil
        ended.phase = .ended
        ended.location = nil
        ended.time = CFAbsoluteTimeGetCurrent()
        grabHandler?(ended)
    }

    private func sync() {
        let live = liveConsumers
        let mask = live.reduce(CGEventMask(0)) { $0 | $1.mask }
        if mask == 0 { refusedMask = nil }
        if let old = tap, !started || mask == 0 || mask != tapMask {
            // A torn-down tap's router ends nothing it owned, so
            // the front ends it here, as a re-enable would.
            old.stop()
            tap = nil
            tapMask = 0
            endGrab()
        }
        guard started, mask != 0, refusedMask != mask else { return }
        if tap == nil {
            tapGeneration += 1
            let generation = tapGeneration
            tap = makeTap(mask) { [weak self] delivery in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self?.receive(delivery, fromTap: generation)
                    }
                }
            }
            tapMask = tap == nil ? 0 : mask
            refusedMask = tap == nil ? mask : nil
            if tap == nil { endGrab() }
            onLog(
                tap == nil
                    ? "pointer tap: refused by macOS (Accessibility?)"
                    : "pointer tap: installed"
            )
        }
        tap?.setSnapshot(
            PointerTapSnapshot(
                grab: live.contains(.grab) ? grabSettings : nil
            )
        )
    }
}
