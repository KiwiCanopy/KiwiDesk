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
/// Sizes are applied stepwise, split by direction: a
/// shrinking window takes its target size on the first frame,
/// a growing one holds its start size until halfway and then
/// grows in one frame, where the ongoing slide masks the jump.
/// Every other frame is position-only — one AX call, and the
/// target app never re-lays-out its content mid-flight. The
/// grow direction's policy is swappable (`growPolicy`, #47) for
/// on-device comparison; the size math lives in `GrowSize`.
@MainActor
public final class AnimationEngine {
    /// Applies one interpolated frame to a real window.
    /// `setSize` marks the rare frames that change size (a
    /// size step and the final frame); all others are
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

    /// Fired when one window's animation reaches its exact target
    /// (the settle frame), with that target. The strand detector
    /// (#47 safety net) reads the window back after a grace and
    /// logs if the app didn't actually land there. Not fired on
    /// cancel/teardown — only a clean settle has a target to check.
    public var onWindowSettled: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// Test seam: when false, `animate` applies the target
    /// frame synchronously instead of spring-animating it, so
    /// unit tests get deterministic placement without driving
    /// the display-link clock. Not reachable from config — the
    /// instant path can't reliably place windows on slow-AX
    /// apps, so animation is always on in production.
    var isEnabled = true

    /// General animation duration in ms, clamped to 50–1000.
    /// Maps onto the spring's response time (250 ms = 0.35 s).
    /// Synced from `AnimationSettings.durationMS` on profile
    /// apply; also set directly by `animations.set_duration`.
    public var durationMS: Int {
        get { storedDurationMS }
        set { storedDurationMS = min(max(newValue, 50), 1000) }
    }

    /// Scrolling-layout focus-shift speed in ms, clamped
    /// 50–1000. Independent knob so scroll speed and general
    /// animation speed can be tuned separately. Synced from
    /// `AnimationSettings.scrollSpeedMS` on profile apply.
    public var scrollDurationMS: Int {
        get { storedScrollDurationMS }
        set {
            storedScrollDurationMS =
                min(max(newValue, 50), 1000)
        }
    }

    /// Grow-direction size policy (#47). Default `.throttledSmooth`
    /// at the per-tick rate below — a growing window follows the
    /// spring smoothly. Engine-only (not persisted to a profile),
    /// but Lua-overridable: `animations.set_grow_policy` drops to
    /// `.midSlide` for a session (e.g. from `init.lua`) if a
    /// slow-AX app misbehaves. The GUI never exposes it (expert
    /// knob, like the bars' `dim_factor`).
    public var growPolicy: GrowPolicy = .throttledSmooth

    /// Optional size-set rate cap for `.throttledSmooth`, in Hz.
    /// `nil` (default) = per-tick: the size channel emits every
    /// display tick, keeping pace with the always-per-tick position
    /// channel on any refresh rate (60, 120, …) without a magic
    /// number. A non-nil value throttles *below* the refresh
    /// (clamped 1–120) to bound a slow-AX app's reflow load. No
    /// effect under `.midSlide`.
    public var growRateHz: Int? {
        get { storedGrowRateHz }
        set { storedGrowRateHz = newValue.map { min(max($0, 1), 120) } }
    }

    private var storedDurationMS = 250
    private var storedScrollDurationMS = 250
    private var storedGrowRateHz: Int?
    /// Per-window seconds since the last throttled size-set (#47).
    // Members below are read by the `+Teardown` extension, so they
    // are module-internal rather than file-private.
    var sizeElapsed: [WindowID: TimeInterval] = [:]
    var animations: [DisplayID: [WindowID: FrameAnimation]] = [:]
    var drivers: [DisplayID: DisplayLinkDriver] = [:]
    /// Last rounded frame sent per window, for no-op skipping.
    var lastApplied: [WindowID: CGRect] = [:]
    /// The size a window actually has on screen right now:
    /// per axis, the target size once shrinking or past
    /// halfway, otherwise the start size held until then.
    var heldSize: [WindowID: CGSize] = [:]

    public init() {}

    public var activeCount: Int {
        animations.values.reduce(0) { $0 + $1.count }
    }

    /// Whether a window is currently being animated. Used to
    /// tell our own frame updates apart from user drags.
    public func isAnimating(window: WindowID) -> Bool {
        animations.values.contains { $0[window] != nil }
    }

    /// The frame a window's in-flight animation is heading to,
    /// nil when idle. Lets an instant frame-set skip a window
    /// already sliding to the same target (#207 exit slide).
    public func targetFrame(window: WindowID) -> CGRect? {
        for perWindow in animations.values {
            if let animation = perWindow[window] {
                return animation.targetFrame
            }
        }
        return nil
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
                // visible mid-flight size snap.
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

    // MARK: - Internals

    /// Drops all per-window bookkeeping for `id` (no-op skip cache,
    /// held size, throttle accumulator). Shared by every teardown
    /// path so a new per-window map can't be forgotten in one.
    func clearState(_ id: WindowID) {
        lastApplied[id] = nil
        heldSize[id] = nil
        sizeElapsed[id] = nil
    }

    @discardableResult
    func removeAnimation(
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

    func tick(display: DisplayID, dt: TimeInterval) {
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
                clearState(id)
                onWindowSettled(id, animation.frame)
                onAnimationEnd(id)
            } else {
                // Stepwise size, split per axis (issue #45).
                // A shrinking axis takes its target size on the
                // first frame — mid-flight overlap clears at
                // once (siblings yielding room to a newly
                // opened window). The grow direction follows the
                // active `growPolicy`: `.throttledSmooth` (#47, the
                // default) resamples the spring each tick (or at a
                // capped rate); `.midSlide` (the legacy fallback)
                // instead lands a single size-set mid-flight, where
                // the ongoing slide masks the jump.
                // Interpolating per tick would instead make slow
                // AX responders (Electron/WebKit) re-lay-out
                // continuously and fall seconds behind, stranding
                // the window mid-size — the cap bounds that load.
                // Pure moves keep the sizes equal, so no resize is
                // emitted.
                let held =
                    heldSize[id]
                    ?? Self.rounded(animation.frame).size
                let stepped = GrowSize.step(
                    policy: growPolicy,
                    held: held,
                    target: animation.targetFrame.size,
                    spring: animation.frame.size,
                    pastHalfway: animation.pastHalfway,
                    rateHz: storedGrowRateHz,
                    elapsed: sizeElapsed[id] ?? 0,
                    dt: dt
                )
                sizeElapsed[id] = stepped.elapsed
                let size = stepped.size
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
    func notifyIfIdle() {
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
