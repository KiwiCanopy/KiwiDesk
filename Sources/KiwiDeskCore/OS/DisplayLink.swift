import AppKit
import QuartzCore

/// Frame clock bound to one monitor.
///
/// KiwiDesk runs **one DisplayLink per monitor** so mixed
/// refresh-rate setups (60 Hz + 120 Hz) each animate at their
/// native cadence (see AGENTS.md guardrails). Built on the
/// macOS 14 `NSScreen.displayLink` API, which tracks the
/// screen's refresh rate automatically.
@MainActor
public final class DisplayLinkDriver {
    public typealias Tick = @MainActor (_ dt: TimeInterval) -> Void

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onTick: Tick

    public private(set) var isRunning = false

    public init(screen: NSScreen, onTick: @escaping Tick) {
        self.onTick = onTick
        let link = screen.displayLink(
            target: self,
            selector: #selector(fire(_:))
        )
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        self.link = link
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        lastTimestamp = nil
        link?.isPaused = false
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        link?.isPaused = true
    }

    /// Detaches from the run loop; the driver is unusable
    /// afterwards.
    public func invalidate() {
        link?.invalidate()
        link = nil
        isRunning = false
    }

    @objc private func fire(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastTimestamp = now }
        guard let last = lastTimestamp else {
            // First tick after start: no dt yet.
            return
        }
        let dt = now - last
        guard dt > 0 else { return }
        // Clamp huge gaps (e.g. after sleep) to one nominal
        // frame so springs never explode.
        let nominal = link.targetTimestamp - now
        onTick(min(dt, max(nominal, 1.0 / 30.0)))
    }
}
