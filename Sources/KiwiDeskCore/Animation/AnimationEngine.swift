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
/// The size channel steps under two orthogonal inputs, and the
/// math for both lives in `SizeStep`. `sizePolicy` (#47) is
/// engine-wide and swappable for on-device comparison: the
/// shipping `.throttledSmooth` follows the spring, the legacy
/// `.midSlide` lands one size-set mid-flight. `BatchSizing` (#593)
/// is per animation and only ever loosens the shrink direction —
/// `.mayInstantSize` keeps the #45 first-frame snap so a sibling yielding
/// room clears at once, `.allSpringSized` lets a shrinking axis follow the
/// spring where nothing in the batch is instantly sized. Frames
/// that change no size are position-only — one AX call, and the
/// target app never re-lays-out its content mid-flight.
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
    /// cancel/teardown — those have no target to check. A
    /// force-settled animation (either net, #611) does fire it:
    /// `apply` wrote the exact target, so the read-back is as
    /// meaningful as after a clean settle.
    public var onWindowSettled: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// Log line consumer, wired to `KiwiCore.onLog` at bootstrap
    /// like every other subsystem's. It exists for the two
    /// force-settle nets (#611): both remove a window from a
    /// wedged state, and a net that fires silently converts the
    /// loud failure that made #599 findable into a quiet one —
    /// leaving only a visible jump and no way to tell a rescue
    /// from a retile. Unwired it goes to syslog rather than
    /// nowhere (`CoreLog`, #624), so a unit suite that never
    /// sets it prints the rescue instead of swallowing it.
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Test seam: when false, `animate` applies the target
    /// frame synchronously instead of spring-animating it, so
    /// unit tests get deterministic placement without driving
    /// the display-link clock. Not reachable from config — the
    /// instant path can't reliably place windows on slow-AX
    /// apps, so animation is always on in production.
    var isEnabled = true

    /// Whether macOS Reduce Motion is on — when true, `animate`
    /// snaps to the target instantly (Apple's contract for the
    /// setting). A seam defaulting to `false` so a host's system
    /// setting can't skew unit tests; `KiwiCore` wires the real
    /// `NSWorkspace` read in production.
    var reduceMotion: @MainActor () -> Bool = { false }

    /// General animation duration in ms, clamped to 50–1000.
    /// Maps onto the spring's response time (150 ms = 0.21 s).
    /// Synced from `AnimationSettings.durationMS` on profile
    /// apply; also set directly by `animations.set_duration`.
    public var durationMS: Int {
        get { storedDurationMS }
        set { storedDurationMS = min(max(newValue, 50), 1000) }
    }

    /// Scrolling-layout focus-shift duration in ms, clamped
    /// 50–1000. Independent knob so the scroll and the general
    /// animation can be tuned separately. Synced from
    /// `AnimationSettings.scrollDurationMS` on profile apply.
    public var scrollDurationMS: Int {
        get { storedScrollDurationMS }
        set {
            storedScrollDurationMS =
                min(max(newValue, 50), 1000)
        }
    }

    /// Size-channel policy (#47). Default `.throttledSmooth` at
    /// the per-tick rate below — a growing window follows the
    /// spring smoothly, and so does a shrinking one on a
    /// `.allSpringSized`-marked animation (#593). Engine-only (not
    /// persisted to a profile), but Lua-overridable:
    /// `animations.set_size_policy` drops to
    /// `.midSlide` for a session (e.g. from `init.lua`) if a
    /// slow-AX app misbehaves. The GUI never exposes it (expert
    /// knob, like the bars' `dim_factor`).
    public var sizePolicy: SizePolicy = .throttledSmooth

    /// Optional size-set rate cap for `.throttledSmooth`, in Hz.
    /// `nil` (default) = per-tick: the size channel emits every
    /// display tick, keeping pace with the always-per-tick position
    /// channel on any refresh rate (60, 120, …) without a magic
    /// number. A non-nil value throttles *below* the refresh
    /// (clamped 1–120) to bound a slow-AX app's reflow load. No
    /// effect under `.midSlide`.
    public var sizeRateHz: Int? {
        get { storedSizeRateHz }
        set { storedSizeRateHz = newValue.map { min(max($0, 1), 120) } }
    }

    private var storedDurationMS = 150
    private var storedScrollDurationMS = 150
    // Internal: the tick loop reads it from `+Tick`.
    var storedSizeRateHz: Int?
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
    ///
    /// `sizing` is why the caller is animating (#593), and it
    /// only ever loosens the shrink direction: `.mayInstantSize` (the
    /// default) keeps the #45 first-frame snap, `.allSpringSized` lets a
    /// shrinking axis follow the spring. It is deliberately NOT
    /// derivable from `isNewWindow` — that flag marks the
    /// *newly-opened* window and is consumed right here to pre-set
    /// `heldSize`, while a make-room shrink hits the **siblings**,
    /// which retile with `isNewWindow: false`.
    public func animate(
        window: WindowID,
        on screen: NSScreen,
        from current: CGRect,
        to target: CGRect,
        isNewWindow: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
        // A non-finite target can only come from garbage upstream
        // (a NaN layout rect, a bad AX read), and it is worse than
        // useless: the spring would never converge to it, and
        // `FrameAnimation`'s non-finite net cannot recover — it
        // assigns the target onto the position, so a NaN target
        // reaches AX as a NaN frame. Refuse the animation and
        // leave the window where it is (#599).
        guard Self.isRenderable(target) else {
            cancel(window: window)
            return
        }
        guard isEnabled, !reduceMotion() else {
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
            // Taking on a promise the previous pass did not make
            // re-seats the size springs onto what is actually on
            // screen first: an unpromised shrink renders `target`
            // from frame 1 while the springs travel on, so the
            // promised step would read a stale, larger size and
            // jump the window back up — #45 across batches.
            // `reseatSize` argues it in full. The held size falls
            // back to the rendered frame the way the tick loop's
            // does, so a missing entry cannot silently skip the
            // re-seat and let the jump through.
            if sizing == .allSpringSized,
                existing.sizing == .mayInstantSize
            {
                existing.reseatSize(
                    heldSize[window]
                        ?? Self.rounded(existing.frame).size
                )
            }
            // Newest promise wins: a pass that promises nothing,
            // interrupting one that did, restores the snap (#593).
            existing.retarget(to: target, sizing: sizing)
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
                        spring: spring,
                        sizing: sizing
                    )
            } else {
                heldSize[window] = current.size
                animations[display, default: [:]][window] =
                    FrameAnimation(
                        from: current,
                        to: target,
                        spring: spring,
                        sizing: sizing
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
}
