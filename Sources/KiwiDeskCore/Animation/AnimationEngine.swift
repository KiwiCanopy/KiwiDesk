import AppKit
import CoreGraphics

/// Spring-based window animation system.
///
/// Drives `FrameAnimation`s from one `DisplayLinkDriver` per
/// monitor. Frames are delivered through the `apply` closure
/// (wired to `WindowControl.setFrame` by the app). Starting an
/// animation for a window that is already animating retargets
/// it in place: position and velocity carry over, so an
/// interrupt never causes a visual jump.
@MainActor
public final class AnimationEngine {
    /// Applies one interpolated frame to a real window.
    public var apply: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// `enable_animations`: when false, frames apply instantly.
    public var isEnabled = true

    /// Animation duration in ms, clamped to 50–1000.
    /// Maps onto the spring's response time (250 ms = 0.35 s).
    public var durationMS: Int {
        get { storedDurationMS }
        set { storedDurationMS = min(max(newValue, 50), 1000) }
    }

    private var storedDurationMS = 250
    private var animations: [DisplayID: [WindowID: FrameAnimation]] = [:]
    private var drivers: [DisplayID: DisplayLinkDriver] = [:]

    public init() {}

    public var activeCount: Int {
        animations.values.reduce(0) { $0 + $1.count }
    }

    /// Whether a window is currently being animated. Used to
    /// tell our own frame updates apart from user drags.
    public func isAnimating(window: WindowID) -> Bool {
        animations.values.contains { $0[window] != nil }
    }

    private var spring: Spring {
        Spring(
            response: Double(storedDurationMS) / 1000 * 1.4,
            dampingFraction: 0.85
        )
    }

    // MARK: - Public API

    /// Animates a window to a target frame on a given screen.
    public func animate(
        window: WindowID,
        on screen: NSScreen,
        from current: CGRect,
        to target: CGRect
    ) {
        guard isEnabled else {
            cancel(window: window)
            apply(window, target)
            return
        }
        guard let display = screen.kiwiDisplay?.id else {
            apply(window, target)
            return
        }
        if var existing = removeAnimation(for: window) {
            existing.retarget(to: target)
            animations[display, default: [:]][window] = existing
        } else {
            animations[display, default: [:]][window] =
                FrameAnimation(
                    from: current,
                    to: target,
                    spring: spring
                )
        }
        startDriver(for: display, screen: screen)
    }

    /// Stops animating a window, leaving it where it is.
    public func cancel(window: WindowID) {
        removeAnimation(for: window)
    }

    /// Stops everything, snapping to targets when enabled.
    public func cancelAll(snapToTargets: Bool = false) {
        if snapToTargets {
            for perWindow in animations.values {
                for (id, animation) in perWindow {
                    apply(id, animation.targetFrame)
                }
            }
        }
        animations = [:]
        for driver in drivers.values {
            driver.stop()
        }
    }

    /// Drops display links for disconnected monitors. Their
    /// in-flight animations complete instantly.
    public func displaysChanged() {
        let connected = Set(
            NSScreen.screens.compactMap { $0.kiwiDisplay?.id }
        )
        for display in Array(drivers.keys)
        where !connected.contains(display) {
            drivers[display]?.invalidate()
            drivers[display] = nil
            for (id, animation) in animations[display] ?? [:] {
                apply(id, animation.targetFrame)
            }
            animations[display] = nil
        }
    }

    // MARK: - Internals

    @discardableResult
    private func removeAnimation(
        for window: WindowID
    ) -> FrameAnimation? {
        for display in animations.keys {
            if let found = animations[display]?
                .removeValue(forKey: window)
            {
                return found
            }
        }
        return nil
    }

    private func startDriver(
        for display: DisplayID,
        screen: NSScreen
    ) {
        if drivers[display] == nil {
            drivers[display] = DisplayLinkDriver(
                screen: screen
            ) { [weak self] dt in
                self?.tick(display: display, dt: dt)
            }
        }
        drivers[display]?.start()
    }

    private func tick(display: DisplayID, dt: TimeInterval) {
        guard var perWindow = animations[display],
            !perWindow.isEmpty
        else {
            drivers[display]?.stop()
            return
        }
        for (id, var animation) in perWindow {
            let settled = animation.step(dt: dt)
            apply(id, animation.frame)
            if settled {
                perWindow[id] = nil
            } else {
                perWindow[id] = animation
            }
        }
        animations[display] = perWindow
        if perWindow.isEmpty {
            drivers[display]?.stop()
        }
    }
}
