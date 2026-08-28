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

    /// Where a starved-clock report goes. Defaults LIVE, the
    /// `onLog` idiom (core-boundaries.md), so **every** driver
    /// reports by default rather than only the one an owner
    /// remembered to wire: there are two construction sites —
    /// `AnimationEngine` and `BorderBumpAnimator` — both riding
    /// the same main run loop and both able to observe the same
    /// stall, so a bump-only period would otherwise be silent
    /// about it (review, #1084). A consumer with its own sink
    /// redirects this; it does not have to opt in.
    var onLog: @MainActor (String) -> Void = CoreLog.write

    /// This driver's display, for the report — captured at
    /// init because a stall is per-clock and a reader with two
    /// monitors needs to know which one stopped.
    private let displayID: CGDirectDisplayID

    /// Well past a frame at any refresh rate this runs at —
    /// 120 Hz is 8 ms, 60 Hz is 17 ms, and ProMotion's slowest
    /// advertised cadence is 24 Hz (42 ms). A gap this size is
    /// not a rate change; it is the clock not being serviced.
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

    /// The stall decision and its sentence, pure so it can be
    /// tested without a `CADisplayLink` — `fire` needs a real
    /// screen, and tests.md keeps a suite off the machine
    /// (`DisplayLinkStallTests`). Nil below the threshold.
    /// `nonisolated` because it touches nothing but its
    /// arguments — the actor buys it nothing and would cost the
    /// suite a hop.
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
        // deliberate pause is not a stall, and reporting the
        // whole idle span as one would out-rank every real
        // entry in a log (review, #1084).
        lastTimestamp = nil
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
        if let line = Self.stallReport(
            gap: dt,
            displayID: displayID
        ) {
            onLog(line)
        }
        // Clamp huge gaps (e.g. after sleep) to one nominal
        // frame so springs never explode.
        let nominal = link.targetTimestamp - now
        onTick(min(dt, max(nominal, 1.0 / 30.0)))
    }
}
