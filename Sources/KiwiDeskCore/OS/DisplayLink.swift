import AppKit
import QuartzCore

/// Frame clock driver bound to a single monitor (`NSScreen.displayLink`).
@MainActor
public final class DisplayLinkDriver {
    public typealias Tick = @MainActor (_ dt: TimeInterval) -> Void

    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private let onTick: Tick

    /// Sink for starved-clock diagnostics. Defaults LIVE
    /// (`CoreLog.write`) so EVERY driver reports — there are two
    /// construction sites riding the same run loop, and a
    /// bump-only period would otherwise be silent
    /// (`core-boundaries.md`, #1084).
    var onLog: @MainActor (String) -> Void = CoreLog.write

    private let displayID: CGDirectDisplayID

    /// Stall threshold. Well past a frame at any rate this runs
    /// at (120 Hz is 8 ms, ProMotion's slowest is 42 ms): a gap
    /// this size is not a rate change, it is the clock not being
    /// serviced.
    nonisolated private static let stallThreshold: TimeInterval = 0.1

    public private(set) var isRunning = false

    public init(screen: NSScreen, onTick: @escaping Tick) {
        self.onTick = onTick
        self.displayID =
            (screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber)?.uint32Value ?? 0
        let link = screen.displayLink(
            target: self,
            selector: #selector(fire(_:))
        )
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        self.link = link
    }

    /// Formats stall report string when tick gap exceeds threshold
    /// (`DisplayLinkStallTests`).
    nonisolated static func stallReport(
        gap: TimeInterval,
        displayID: CGDirectDisplayID
    ) -> String? {
        guard gap > stallThreshold else { return nil }
        return "frame clock stalled \(Int(gap * 1000))ms on "
            + "display \(displayID)"
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
        // The next start measures from its own first tick: a
        // deliberate pause is not a stall, and reporting the idle
        // span would out-rank every real entry (review, #1084).
        lastTimestamp = nil
    }

    /// Detaches from the run loop; the driver is unusable afterwards.
    public func invalidate() {
        link?.invalidate()
        link = nil
        isRunning = false
    }

    @objc private func fire(_ link: CADisplayLink) {
        let now = link.timestamp
        defer { lastTimestamp = now }
        if let last = lastTimestamp,
            let line = Self.stallReport(
                gap: now - last,
                displayID: displayID
            )
        {
            onLog(line)
        }
        guard
            let dt = Self.step(
                now: now,
                last: lastTimestamp,
                target: link.targetTimestamp
            )
        else { return }
        onTick(dt)
    }

    /// The time a tick advances the clock by, nil for none. The
    /// first tick after a start steps one nominal frame, so motion
    /// begins on the first frame shown (#1878); later ticks take
    /// the gap, clamped to a frame so a gap after sleep never
    /// explodes a spring.
    nonisolated static func step(
        now: CFTimeInterval,
        last: CFTimeInterval?,
        target: CFTimeInterval
    ) -> TimeInterval? {
        let nominal = target - now
        guard let last else { return nominal > 0 ? nominal : nil }
        let dt = now - last
        guard dt > 0 else { return nil }
        return min(dt, max(nominal, 1.0 / 30.0))
    }
}
