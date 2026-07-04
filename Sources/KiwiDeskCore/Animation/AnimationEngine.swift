import AppKit
import CoreGraphics

/// Spring-based window animation system.
///
/// Drives `FrameAnimation`s from one `DisplayLinkDriver` per
/// monitor. Frames are delivered through the `apply` closure
/// (wired to `FrameApplier` by the tiler). Starting an
/// animation for a window that is already animating retargets
/// it in place: position and velocity carry over, so an
/// interrupt never causes a visual jump.
///
/// Frames are rounded to whole pixels and consecutive
/// duplicates are skipped: sub-pixel deltas don't render but
/// each one would still cost a blocking AX round-trip.
///
/// Sizes are applied stepwise (rift-style): a window keeps
/// its size until the animation passes the halfway mark, then
/// jumps to the target size. Every other frame is
/// position-only — one AX call, and the target app never
/// re-lays-out its content mid-flight.
@MainActor
public final class AnimationEngine {
    /// Applies one interpolated frame to a real window.
    /// `setSize` marks the rare frames that change size (the
    /// halfway switch and the final frame); all others are
    /// position-only.
    public var apply: @MainActor (WindowID, CGRect, Bool) -> Void =
        { _, _, _ in }

    /// Fired when a window starts / stops animating. Wired to
    /// the per-app `AXEnhancedUserInterface` toggling.
    public var onAnimationStart: @MainActor (WindowID) -> Void =
        { _ in }
    public var onAnimationEnd: @MainActor (WindowID) -> Void =
        { _ in }

    /// Fired when the last running animation ends (settled,
    /// cancelled, or display removed). Used for work that
    /// must wait until windows stop moving, like z-order
    /// restoration.
    public var onAllAnimationsEnded: @MainActor () -> Void = {}

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
    /// Last rounded frame sent per window, for no-op skipping.
    private var lastApplied: [WindowID: CGRect] = [:]
    /// The size a window actually has on screen right now;
    /// held until the halfway switch to the target size.
    private var heldSize: [WindowID: CGSize] = [:]

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
        to target: CGRect,
        isNewWindow: Bool = false
    ) {
        guard isEnabled else {
            cancel(window: window)
            apply(window, target, true)
            return
        }
        guard let display = screen.kiwiDisplay?.id else {
            cancel(window: window)
            apply(window, target, true)
            return
        }
        if var existing = removeAnimation(for: window) {
            existing.retarget(to: target)
            animations[display, default: [:]][window] = existing
        } else {
            onAnimationStart(window)
            if isNewWindow {
                // Pre-set the target size at the current position
                // so only position slides. The app resizes once
                // at its spawn point, then moves smoothly — no
                // visible halfway size snap.
                heldSize[window] = target.size
                apply(
                    window,
                    CGRect(
                        origin: current.origin,
                        size: target.size
                    ),
                    true
                )
                animations[display, default: [:]][window] =
                    FrameAnimation(
                        from: CGRect(
                            origin: current.origin,
                            size: target.size
                        ),
                        to: target,
                        spring: spring
                    )
            } else {
                heldSize[window] = current.size
                animations[display, default: [:]][window] =
                    FrameAnimation(
                        from: current,
                        to: target,
                        spring: spring
                    )
            }
        }
        startDriver(for: display, screen: screen)
    }

    /// Stops animating a window, leaving it where it is.
    public func cancel(window: WindowID) {
        if removeAnimation(for: window) != nil {
            lastApplied[window] = nil
            heldSize[window] = nil
            onAnimationEnd(window)
            notifyIfIdle()
        }
    }

    /// Stops everything, snapping to targets when enabled.
    public func cancelAll(snapToTargets: Bool = false) {
        for perWindow in animations.values {
            for (id, animation) in perWindow {
                if snapToTargets {
                    apply(id, animation.targetFrame, true)
                }
                onAnimationEnd(id)
            }
        }
        let wasActive = activeCount > 0
        animations = [:]
        lastApplied = [:]
        heldSize = [:]
        for driver in drivers.values {
            driver.stop()
        }
        if wasActive {
            onAllAnimationsEnded()
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
            var removedAny = false
            for (id, animation) in animations[display] ?? [:] {
                apply(id, animation.targetFrame, true)
                lastApplied[id] = nil
                heldSize[id] = nil
                onAnimationEnd(id)
                removedAny = true
            }
            animations[display] = nil
            if removedAny {
                notifyIfIdle()
            }
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
            if settled {
                // Exact target, unrounded: layout output is
                // the source of truth for the final frame.
                apply(id, animation.frame, true)
                perWindow[id] = nil
                lastApplied[id] = nil
                heldSize[id] = nil
                onAnimationEnd(id)
            } else {
                // Stepwise size: hold the on-screen size until
                // halfway, then switch to the target size. For
                // pure moves the sizes match and no resize is
                // ever emitted.
                //
                // For pure resizes (no movement), we animate the
                // size smoothly on every tick to prevent the window
                // from staying static and suddenly jumping.
                let size =
                    animation.isPureResize
                    ? animation.frame.size
                    : (animation.pastHalfway
                        ? animation.targetFrame.size
                        : heldSize[id]
                            ?? Self.rounded(animation.frame).size)
                let setSize = size != heldSize[id]
                heldSize[id] = size
                let frame = CGRect(
                    x: animation.frame.origin.x.rounded(),
                    y: animation.frame.origin.y.rounded(),
                    width: size.width.rounded(),
                    height: size.height.rounded()
                )
                if setSize || lastApplied[id] != frame {
                    lastApplied[id] = frame
                    apply(id, frame, setSize)
                }
                perWindow[id] = animation
            }
        }
        animations[display] = perWindow
        if perWindow.isEmpty {
            drivers[display]?.stop()
            notifyIfIdle()
        }
    }

    /// Fires `onAllAnimationsEnded` when nothing animates
    /// anymore, on any display.
    private func notifyIfIdle() {
        if activeCount == 0 {
            onAllAnimationsEnded()
        }
    }

    private static func rounded(_ frame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x.rounded(),
            y: frame.origin.y.rounded(),
            width: frame.width.rounded(),
            height: frame.height.rounded()
        )
    }
}
