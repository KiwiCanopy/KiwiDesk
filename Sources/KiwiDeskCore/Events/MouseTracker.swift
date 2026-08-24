import AppKit

/// Remembers the most recent left-button press via event
/// monitors, and re-emits each press through `onLeftMouseDown`
/// for consumers that react to a click's location (the #446
/// display-focus follow).
///
/// The press is needed to classify the trailing AX resize event
/// of a fast mouse gesture: it arrives after the button release,
/// so "is the button down?" alone would drop it. Only clicks are
/// observed (two event types, a handful per interaction) — never
/// mouse movement — so the cost is negligible.
///
/// **Two monitors, deliberately asymmetric (#953).** A global
/// monitor never sees events routed to our OWN windows, so a
/// press on the tiled Settings window's resize border went
/// unrecorded and its gesture could not be classified — the
/// own window was the one tiled window whose drags had no
/// press. The local monitor closes that, and records the press
/// ONLY: `onLeftMouseDown` stays global-fed on purpose,
/// because its consumers are built on that blindness —
/// `followDisplayUnderClick` gets its bar-overlay exemption
/// for free from it (#446), and `lastLeftClick` is the click
/// provenance the sibling distrust and the ignored-panel
/// escape read (#496, #687, #951). Widening the fan-out is a
/// separate ruling from making a gesture classifiable.
@MainActor
public final class MouseTracker {
    public struct Press {
        /// Where the button went down, in AX coordinates.
        public let location: CGPoint
        public let downAt: Date
        public var upAt: Date?
    }

    public private(set) var press: Press?
    private var monitors: [Any] = []

    /// Fired on every left-button press, with the press location
    /// in Cocoa screen coordinates (bottom-left origin) — the
    /// space the `NSScreen` frames live in. Drives the
    /// display-focus follow (#446): a bare click on another
    /// monitor's empty desktop moves the "focused display". Only
    /// clicks reach here (never mouse movement), so it is cheap.
    public var onLeftMouseDown: ((CGPoint) -> Void)?

    public init() {}

    public func start() {
        guard monitors.isEmpty else { return }
        let down = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            let location = event.locationInWindow
            Task { @MainActor in
                self?.recordDown(at: location)
                self?.onLeftMouseDown?(location)
            }
        }
        let up = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseUp
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordUp()
            }
        }
        // Our own windows' presses, which the global pair never
        // sees (#953). Press bookkeeping only — see the type
        // doc for why `onLeftMouseDown` is not fired here — and
        // the event is always passed through untouched, so the
        // click still reaches the control the user aimed at.
        //
        // A local monitor runs inside the app's own event
        // dispatch, which is the main thread by AppKit's
        // contract — the same argument `axCallback` makes — so
        // the press is recorded inline rather than hopped
        // through a `Task`: the handler must hand the event
        // back synchronously anyway, and the conversion below
        // reads main-actor AppKit state.
        let localDown = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.recordDown(
                    at: Self.screenLocation(of: event)
                )
            }
            return event
        }
        let localUp = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseUp
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.recordUp() }
            return event
        }
        monitors = [down, up, localDown, localUp]
            .compactMap { $0 }
    }

    /// A local monitor's event carries WINDOW coordinates when
    /// it has a window (a global monitor's never does, which is
    /// why the global pair can read `locationInWindow` as a
    /// screen point). Convert, so both paths hand `recordDown`
    /// the same Cocoa screen space.
    private static func screenLocation(
        of event: NSEvent
    ) -> CGPoint {
        guard let window = event.window else {
            return event.locationInWindow
        }
        return window.convertPoint(
            toScreen: event.locationInWindow
        )
    }

    public func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        press = nil
    }

    /// Global monitor events carry screen coordinates in
    /// Cocoa space (no window); flip into AX space.
    private func recordDown(at location: CGPoint) {
        press = Press(
            location: GeometryUtils.axPoint(location),
            downAt: Date()
        )
    }

    private func recordUp() {
        press?.upAt = Date()
    }

    /// Test seam: seeds the last press directly (already in AX
    /// coordinates), standing in for the global mouse-down
    /// monitor, which does not fire under unit tests.
    func seedPress(at location: CGPoint) {
        press = Press(location: location, downAt: Date())
    }
}
