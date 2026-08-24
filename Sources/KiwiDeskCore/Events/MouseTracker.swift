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
/// monitor never sees an event routed to our OWN windows, so a
/// press on the tiled Settings window's resize border went
/// unrecorded and its gesture could not be classified. The
/// local arm closes that, gated on the tiling mark and
/// recording the press only — it never fires
/// `onLeftMouseDown`. The argument for both halves of that
/// sentence lives once, in
/// `.claude/rules/input-and-animation.md` under #953; do not
/// reproduce it here.
@MainActor
public final class MouseTracker {
    public struct Press {
        /// Which monitor arm opened this press. The two
        /// arms answer disjoint worlds — a global monitor
        /// never sees an event routed to our own windows —
        /// so the arm IS the provenance, and it is what the
        /// release and the click fan-out both reason from
        /// rather than re-deriving anything from the event.
        public enum Origin: Sendable {
            /// Any other application's window.
            case otherApp
            /// The one own window that tiles (#953). Every
            /// other own window records no press at all.
            case ownWindow
        }

        /// Where the button went down, in AX coordinates.
        public let location: CGPoint
        public let downAt: Date
        public let origin: Origin
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
    ///
    /// **Only a `.otherApp` press reaches it** — the consumers
    /// are built on a global monitor's blindness to our own
    /// windows (#446, #496, #687, #951), so the stand-down is
    /// argued from the press's own provenance rather than from
    /// which closure happened to call `recordDown`.
    public var onLeftMouseDown: ((CGPoint) -> Void)?

    public init() {}

    public func start() {
        guard monitors.isEmpty else { return }
        let down = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            let location = event.locationInWindow
            Task { @MainActor in
                self?.recordDown(at: location, from: .otherApp)
            }
        }
        let up = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseUp
        ) { [weak self] _ in
            Task { @MainActor in
                self?.recordUp(from: .otherApp)
            }
        }
        // Our own windows' presses, which the global pair
        // never sees (#953). AppKit dispatches a local monitor
        // from the main thread's own event dispatch and wants
        // the event handed back synchronously, so the AppKit
        // read happens inline under `assumeIsolated` — but the
        // STORE is enqueued exactly like the global arms', so
        // one scheduling discipline orders all four writes and
        // a queued `up` can never stamp a press recorded after
        // it.
        let localDown = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] event in
            let location = MainActor.assumeIsolated {
                Self.tilingWindowPress(of: event)
            }
            if let location {
                Task { @MainActor in
                    self?.recordDown(
                        at: location,
                        from: .ownWindow
                    )
                }
            }
            return event
        }
        // The release closes a press its OWN arm opened, and
        // that is provenance, not the mark: `press` outlives
        // every gesture (only `stop()` clears it), so an
        // ungated release re-stamps `upAt` on whatever press
        // is still sitting there — after the down half started
        // discriminating, a click on a bar item would refresh
        // a third-party press recorded minutes earlier and
        // hand `isResizeGesture` a stale location it reads as
        // fresh. Provenance also survives an up delivered with
        // no window at the end of a frame-resize tracking
        // loop, which a mark-gated release would drop.
        let localUp = NSEvent.addLocalMonitorForEvents(
            matching: .leftMouseUp
        ) { [weak self] event in
            Task { @MainActor in
                self?.recordUp(from: .ownWindow)
            }
            return event
        }
        monitors = [down, up, localDown, localUp]
            .compactMap { $0 }
    }

    /// The press location to record for a local event, or nil
    /// when it is not one this tracker remembers. The AppKit
    /// read; `ownPressLocation` is the decision.
    private static func tilingWindowPress(
        of event: NSEvent
    ) -> CGPoint? {
        ownPressLocation(
            identifier: event.window?.identifier?.rawValue,
            locationInWindow: event.locationInWindow,
            windowFrame: event.window?.frame
        )
    }

    /// Whether a press on one of our own windows is one the
    /// gesture classifiers may reason from, and where it
    /// landed in Cocoa screen space — the pure half, so both
    /// answers are testable without a real `NSEvent`.
    ///
    /// **Per WINDOW, never per process (#678 item 18).** Only
    /// the one own window carrying `OwnWindowTiling.identifier`
    /// takes a layout slot, so only its presses can belong to a
    /// tiled gesture. Every other own window — the bars' item
    /// views take `mouseDown`, and so do the tour, Config
    /// Issues and each `NSOpenPanel` — would otherwise
    /// overwrite the single press slot that `isResizeGesture`
    /// and the resize-vs-move ghost gate read, with a click the
    /// user aimed at chrome.
    ///
    /// A local monitor's event carries WINDOW coordinates when
    /// it has a window (a global monitor's never does, which is
    /// why the global pair reads `locationInWindow` as a screen
    /// point). Converting through the window's own frame origin
    /// is `NSWindow.convertPoint(toScreen:)`'s definition and
    /// keeps this half free of AppKit.
    static func ownPressLocation(
        identifier: String?,
        locationInWindow: CGPoint,
        windowFrame: CGRect?
    ) -> CGPoint? {
        guard identifier == OwnWindowTiling.identifier,
            let windowFrame
        else { return nil }
        return CGPoint(
            x: windowFrame.origin.x + locationInWindow.x,
            y: windowFrame.origin.y + locationInWindow.y
        )
    }

    public func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        press = nil
    }

    /// Both feeders hand this Cocoa screen coordinates — the
    /// global arm's events carry them directly (no window), and
    /// the local arm's are converted by `ownPressLocation`.
    /// Flip into AX space.
    func recordDown(
        at location: CGPoint,
        from origin: Press.Origin
    ) {
        press = Press(
            location: GeometryUtils.axPoint(location),
            downAt: Date(),
            origin: origin
        )
        guard origin == .otherApp else { return }
        onLeftMouseDown?(location)
    }

    /// Closes the open press, if this arm is the one that
    /// opened it. A mismatch is not an error — it is the other
    /// arm's release arriving while this arm's press stands —
    /// and dropping it is the safe direction: `isResizeGesture`
    /// reads the press only through `guard let up = press.upAt`,
    /// so a press left open is inert while one closed by the
    /// wrong arm is read as a gesture that just ended.
    func recordUp(from origin: Press.Origin) {
        guard press?.origin == origin else { return }
        press?.upAt = Date()
    }

    /// Test seam: seeds the last press directly (already in AX
    /// coordinates), standing in for either mouse-down
    /// monitor — neither fires under unit tests.
    ///
    /// Deliberately NOT `recordDown`: it skips the flip (the
    /// point is already AX) and so also skips the fan-out. It
    /// seeds `.otherApp`, which is the arm a `recordUp` must
    /// then name to close it — seed here and release with
    /// `.ownWindow` and nothing closes, correctly.
    func seedPress(at location: CGPoint) {
        press = Press(
            location: location,
            downAt: Date(),
            origin: .otherApp
        )
    }
}
