import AppKit

/// Tracks left-button mouse presses for gesture classification and display
/// focus (#446, #953).
@MainActor
public final class MouseTracker {
    public struct Press {
        /// Monitor origin of press (global vs local, #953).
        public enum Origin: Sendable {
            case otherApp
            /// Single own window that tiles (#953, #678 item 18).
            case ownWindow
        }

        public let location: CGPoint
        public let downAt: Date
        public let origin: Origin
        public var upAt: Date?
    }

    public private(set) var press: Press?
    private var monitors: [Any] = []

    /// Fired on left-mouse-down in Cocoa screen space (#446).
    /// **Only a `.otherApp` press reaches it** — the consumers are
    /// built on a global monitor's blindness to our own windows
    /// (#446, #496, #687, #951), so the stand-down is argued from
    /// the press's own provenance.
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
        // Local monitor arm for own tiled window presses (#953).
        // The AppKit read happens inline (the event must be handed
        // back synchronously) but the STORE is enqueued exactly
        // like the global arms' — one scheduling discipline orders
        // all four writes, so a queued `up` can never stamp a
        // press recorded after it.
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

    private static func tilingWindowPress(
        of event: NSEvent
    ) -> CGPoint? {
        ownPressLocation(
            identifier: event.window?.identifier?.rawValue,
            locationInWindow: event.locationInWindow,
            windowFrame: event.window?.frame
        )
    }

    /// Resolves press location for an own window — per WINDOW,
    /// never per process (#678 item 18): only the one window
    /// carrying `OwnWindowTiling.identifier` takes a layout slot,
    /// and every other own window (bars, tour, panels) would
    /// otherwise overwrite the single press slot with a click the
    /// user aimed at chrome.
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

    /// Records mouse down in AX space; notifies if otherApp (#446, #953).
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

    /// Closes the OPEN press, if this arm opened it (#953).
    /// Openness is not implied by provenance: `press` outlives its
    /// gesture (only `stop()` clears it), so re-stamping a CLOSED
    /// press would push its stale location back inside
    /// `isResizeGesture`'s freshness window — a Space Bar click is
    /// itself a retile, which is the resize the pipeline would
    /// then believe in. Dropping an unmatched release is the safe
    /// direction.
    func recordUp(from origin: Press.Origin) {
        guard press?.origin == origin, press?.upAt == nil
        else { return }
        press?.upAt = Date()
    }

    /// Test seam: seeds press in AX coordinates directly.
    /// Deliberately NOT `recordDown` — it skips the flip and the
    /// fan-out, and seeds `.otherApp`, which a `recordUp` must
    /// then name to close.
    func seedPress(at location: CGPoint) {
        press = Press(
            location: location,
            downAt: Date(),
            origin: .otherApp
        )
    }
}
