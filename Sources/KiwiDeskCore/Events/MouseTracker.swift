import AppKit

/// Remembers the most recent left-button press via global
/// event monitors, and re-emits each press through
/// `onLeftMouseDown` for consumers that react to a click's
/// location (the #446 display-focus follow).
///
/// The press is needed to classify the trailing AX resize event
/// of a fast mouse gesture: it arrives after the button release,
/// so "is the button down?" alone would drop it. Only clicks are
/// observed (two event types, a handful per interaction) — never
/// mouse movement — so the cost is negligible.
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
        monitors = [down, up].compactMap { $0 }
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
