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

    /// Reports a frame that arrived later than `stallThreshold`,
    /// with the RAW gap — the tick itself is clamped before the
    /// engine sees it, so a starved clock is invisible
    /// downstream and every symptom it causes gets attributed
    /// to whatever code happened to be nearby (#1084). Assigned
    /// by `AnimationEngine`, which routes it to its own log
    /// seam; unset it stays silent.
    var onStall: (@MainActor (TimeInterval) -> Void)?

    /// Well past a frame at any refresh rate this runs at —
    /// 120 Hz is 8 ms, 60 Hz is 17 ms, and ProMotion's slowest
    /// advertised cadence is 24 Hz (42 ms). A gap this size is
    /// not a rate change; it is the clock not being serviced.
    private static let stallThreshold: TimeInterval = 0.1

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
        if dt > Self.stallThreshold { onStall?(dt) }
        // Clamp huge gaps (e.g. after sleep) to one nominal
        // frame so springs never explode.
        let nominal = link.targetTimestamp - now
        onTick(min(dt, max(nominal, 1.0 / 30.0)))
    }
}
