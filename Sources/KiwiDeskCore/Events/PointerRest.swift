import AppKit

/// The pointer coming to rest after the user moved it — hover
/// focus's one trigger (#1869). Only a global mouse-moved event
/// arms it, so a warp, a keyboard focus change or a pointer that
/// merely sits over a window never fires it, and jitter within
/// `stillRadius` of the last rest is not travel. KiwiDesk's own
/// warp posts no mouse event, and a rest carries the focus its
/// move armed with (input-and-animation.md).
@MainActor
public final class PointerRest {
    /// How long the pointer rests before the consumer is asked —
    /// `mouse.hover_focus_delay`, written with the rest's switch.
    var dwell: Duration = .milliseconds(
        MouseSettings.defaultHoverFocusDelayMS
    )
    /// Motion within this many points of the last rest is jitter.
    static let stillRadius: CGFloat = 4

    /// Fired once per rest with the pointer's location then, in
    /// Cocoa screen space, and the focus `noteArm` read when the
    /// dwell last armed.
    var onRest: ((CGPoint, WindowID?) -> Void)?
    /// The focus now, read each time a move arms the dwell.
    var noteArm: (() -> WindowID?)?
    /// Installs the global mouse-moved monitor, live in
    /// production and pinned inert by both `makeTestCore` twins
    /// as the scroll tap is (tests.md ▸ machine touch).
    var makeMonitor:
        @MainActor (@escaping @MainActor (CGPoint) -> Void) -> Any? =
            live
    var removeMonitor: (Any) -> Void = { NSEvent.removeMonitor($0) }
    /// The pointer's location now, Cocoa screen space.
    var location: @MainActor () -> CGPoint = { NSEvent.mouseLocation }

    public private(set) var isEnabled = false
    private var running = false
    private var monitor: Any?
    private var lastRest: CGPoint?
    private var lastMove: CGPoint?
    private var armedFocus: WindowID?
    private var timer: Task<Void, Never>?

    public init() {}

    /// Whether a dwell is running — a move armed it and no rest
    /// or stop has ended it yet.
    var isArmed: Bool { timer != nil }

    /// Whether the mouse-moved monitor is installed.
    var isListening: Bool { monitor != nil }

    /// The consumer's switch; the monitor is installed only while
    /// it is on and the tracker runs, so an off setting costs no
    /// event per pointer move.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        sync()
    }

    func start() {
        running = true
        sync()
    }

    func stop() {
        running = false
        sync()
    }

    /// One user pointer move, Cocoa screen space: re-arms the
    /// dwell unless it is jitter around the last rest.
    func moved(to point: CGPoint) {
        if let rest = lastRest,
            hypot(point.x - rest.x, point.y - rest.y)
                <= Self.stillRadius
        {
            return
        }
        lastRest = nil
        armedFocus = noteArm?()
        arm(at: point)
    }

    /// Starts the dwell from `point`. A re-arm keeps the focus the
    /// user's own move armed with, so a focus moved since — a
    /// warp's shortcut — still stands at the rest.
    private func arm(at point: CGPoint) {
        lastMove = point
        timer?.cancel()
        timer = Task { [weak self] in
            guard let dwell = self?.dwell else { return }
            try? await Task.sleep(for: dwell)
            guard !Task.isCancelled else { return }
            self?.rest()
        }
    }

    /// The dwell ran out. A pointer away from the last move it
    /// was heard at kept moving where the monitor is deaf — over
    /// KiwiDesk's own windows — so it re-arms instead.
    func rest() {
        timer = nil
        let point = location()
        if let last = lastMove,
            hypot(point.x - last.x, point.y - last.y) > Self.stillRadius
        {
            arm(at: point)
            return
        }
        lastRest = point
        onRest?(point, armedFocus)
    }

    private func sync() {
        if running, isEnabled {
            guard monitor == nil else { return }
            monitor = makeMonitor { [weak self] in self?.moved(to: $0) }
        } else {
            if let monitor { removeMonitor(monitor) }
            monitor = nil
            timer?.cancel()
            timer = nil
            lastRest = nil
            lastMove = nil
        }
    }

    private static func live(
        _ deliver: @escaping @MainActor (CGPoint) -> Void
    ) -> Any? {
        // A global monitor's event location is in screen space.
        NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) {
            let point = $0.locationInWindow
            Task { @MainActor in deliver(point) }
        }
    }
}
