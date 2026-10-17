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
    /// `mouse.hover_focus_delay`, written through `apply`.
    var dwell: Duration = .milliseconds(
        MouseSettings.defaultHoverFocusDelayMS
    )
    /// Motion within this many points of the last rest is jitter.
    static let stillRadius: CGFloat = 4

    /// Fired once per rest with the pointer's location then, in
    /// Cocoa screen space, and the focus `noteArm` read when the
    /// dwell last armed.
    var onRest: ((CGPoint, WindowID?) -> Void)?
    /// Fronts KiwiDesk's own marked window, by number, after hover
    /// focus commanded its focus — AppKit's half of #1281's raise,
    /// wired by the GUI; a no-op where no GUI runs.
    public var frontOwnWindow: @MainActor (Int) -> Void = { _ in }
    /// The focus now, read each time a move arms the dwell.
    var noteArm: (() -> WindowID?)?
    /// The tracked windows whose frames hold a point (Cocoa screen
    /// space), read from state on every move while a hold is taken
    /// or owed — never a WindowServer read.
    var windowsAt: ((CGPoint) -> Set<WindowID>)?
    /// The windows under the pointer when the first move after a
    /// focus change the pointer did not make arrived (owner ruling
    /// 2026-10-17): a rest on one of them stands down until a move
    /// lands outside all of them, so a nudge never takes the focus
    /// back to the window the pointer was merely left over.
    public private(set) var held: Set<WindowID> = []
    /// Installs the mouse-moved monitors, live in production and
    /// pinned inert by both `makeTestCore` twins as the scroll tap
    /// is (tests.md ▸ machine touch). A move delivered without a
    /// point is read through `location`.
    var makeMonitor:
        @MainActor (@escaping @MainActor (CGPoint?) -> Void) -> Any? =
            live
    var removeMonitor: (Any) -> Void = { monitors in
        for monitor in monitors as? [Any] ?? [monitors] {
            NSEvent.removeMonitor(monitor)
        }
    }
    /// The pointer's location now, Cocoa screen space.
    var location: @MainActor () -> CGPoint = { NSEvent.mouseLocation }

    public private(set) var isEnabled = false
    private var running = false
    private var monitor: Any?
    private var lastRest: CGPoint?
    private var lastMove: CGPoint?
    private var armedFocus: WindowID?
    /// The focus as the last move or rest saw it; unknown until the
    /// first, which takes no hold.
    private var knownFocus: WindowID?
    private var focusKnown = false
    private var timer: Task<Void, Never>?

    public init() {}

    /// Whether a dwell is running — a move armed it and no rest
    /// or stop has ended it yet.
    var isArmed: Bool { timer != nil }

    #if DEBUG
        /// The armed dwell, for a test to await rather than poll
        /// (tests.md, #344); production never reads it. Cleared by
        /// the rest it fires, so read it BEFORE awaiting — nil means
        /// nothing was armed, and awaiting a cancelled one bounds
        /// nothing.
        var pendingDwell: Task<Void, Never>? { timer }
    #endif

    /// Whether the mouse-moved monitor is installed.
    var isListening: Bool { monitor != nil }

    /// The one door from the settings (#1869): the delay and the
    /// switch together, so a new field the rest reads joins here.
    public func apply(_ settings: MouseSettings) {
        dwell = .milliseconds(settings.hoverFocusDelayMS)
        setEnabled(settings.hoverFocus)
    }

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
        updateHold(at: point)
        arm(at: point)
    }

    /// Takes the hold at the first move after the focus moved
    /// without a rest, and releases it once a move leaves every held
    /// window — the hold is the window the pointer was left over,
    /// or one that slid under it.
    private func updateHold(at point: CGPoint) {
        if !focusKnown {
            focusKnown = true
            knownFocus = armedFocus
        } else if armedFocus != knownFocus {
            knownFocus = armedFocus
            held = windowsAt?(point) ?? []
        } else if !held.isEmpty,
            held.isDisjoint(with: windowsAt?(point) ?? [])
        {
            held = []
        }
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
        // A rest that moved the focus moved it on purpose.
        knownFocus = noteArm?()
        focusKnown = true
    }

    private func sync() {
        if running, isEnabled {
            guard monitor == nil else { return }
            monitor = makeMonitor { [weak self] point in
                guard let self else { return }
                self.moved(to: point ?? self.location())
            }
        } else {
            if let monitor { removeMonitor(monitor) }
            monitor = nil
            timer?.cancel()
            timer = nil
            lastRest = nil
            lastMove = nil
            held = []
            knownFocus = nil
            focusKnown = false
        }
    }

    /// Both arms (#2378): moves go to the ACTIVE app, so while
    /// KiwiDesk is active — its Settings window key — only the
    /// local monitor hears the pointer leaving for another window.
    private static func live(
        _ deliver: @escaping @MainActor (CGPoint?) -> Void
    ) -> Any? {
        // A global monitor's event location is in screen space.
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
        ) {
            let point = $0.locationInWindow
            Task { @MainActor in deliver(point) }
        }
        // A local event's location is its window's, so the rest
        // reads the pointer itself.
        let local = NSEvent.addLocalMonitorForEvents(
            matching: .mouseMoved
        ) { event in
            Task { @MainActor in deliver(nil) }
            return event
        }
        return [global, local].compactMap { $0 }
    }
}
