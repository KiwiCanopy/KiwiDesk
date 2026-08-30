import AppKit
import CoreGraphics

/// Spring-based window animation system.
/// Drives `FrameAnimation`s via per-monitor `DisplayLinkDriver`s. Size channel
/// handles `sizePolicy` (#47) and `BatchSizing` (#45, #593).
@MainActor
public final class AnimationEngine {
    /// Applies interpolated frame to window. `setSize` marks frames
    /// altering size.
    public var apply: @MainActor (WindowID, CGRect, Bool) -> Void =
        { _, _, _ in }

    /// Fired when an animation starts/stops (for `AXEnhancedUserInterface`).
    public var onAnimationStart: @MainActor (WindowID) -> Void =
        { _ in }
    public var onAnimationEnd: @MainActor (WindowID) -> Void =
        { _ in }

    /// Fired when the last running animation ends (e.g. for z-order restore).
    public var onAllAnimationsEnded: @MainActor () -> Void = {}

    /// Fired when window reaches exact target (#47, #611).
    public var onWindowSettled: @MainActor (WindowID, CGRect) -> Void =
        { _, _ in }

    /// Log consumer for force-settles and diagnostics (#611, #624).
    public var onLog: @MainActor (String) -> Void = CoreLog.write

    /// Test seam: synchronously snaps to target when false. Not
    /// reachable from config — the instant path can't reliably
    /// place windows on slow-AX apps, so animation is always on
    /// in production.
    var isEnabled = true

    /// Whether macOS Reduce Motion is enabled.
    var reduceMotion: @MainActor () -> Bool = { false }

    /// General animation duration in ms (50–1000).
    public var durationMS: Int {
        get { storedDurationMS }
        set { storedDurationMS = min(max(newValue, 50), 1000) }
    }

    /// Scrolling layout focus shift duration in ms (50–1000).
    public var scrollDurationMS: Int {
        get { storedScrollDurationMS }
        set {
            storedScrollDurationMS =
                min(max(newValue, 50), 1000)
        }
    }

    /// Size-channel policy (#47, #593). Default `.throttledSmooth`.
    public var sizePolicy: SizePolicy = .throttledSmooth

    /// Optional size update rate limit in Hz for `.throttledSmooth` (1–120).
    public var sizeRateHz: Int? {
        get { storedSizeRateHz }
        set { storedSizeRateHz = newValue.map { min(max($0, 1), 120) } }
    }

    private var storedDurationMS = 150
    private var storedScrollDurationMS = 150
    var storedSizeRateHz: Int?
    var sizeElapsed: [WindowID: TimeInterval] = [:]
    var animations: [DisplayID: [WindowID: FrameAnimation]] = [:]
    var drivers: [DisplayID: DisplayLinkDriver] = [:]
    var lastApplied: [WindowID: CGRect] = [:]
    var heldSize: [WindowID: CGSize] = [:]
    /// Commanded base for floating glide accumulation (#1090, #881).
    var glideBase = GlideCommandedBase()

    public init() {}

    public var activeCount: Int {
        animations.values.reduce(0) { $0 + $1.count }
    }

    /// True if window has an active animation.
    public func isAnimating(window: WindowID) -> Bool {
        animations.values.contains { $0[window] != nil }
    }

    /// In-flight target frame for window (#207).
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

    /// Animates window to target frame on screen (#45, #593,
    /// #599). `sizing` is deliberately NOT derivable from
    /// `isNewWindow`: that flag marks the newly-opened window,
    /// while a make-room shrink hits the SIBLINGS, which retile
    /// with `isNewWindow: false`.
    public func animate(
        window: WindowID,
        on screen: NSScreen,
        from current: CGRect,
        to target: CGRect,
        isNewWindow: Bool = false,
        sizing: BatchSizing = .mayInstantSize
    ) {
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
            if sizing == .allSpringSized,
                existing.sizing == .mayInstantSize
            {
                existing.reseatSize(
                    heldSize[window]
                        ?? Self.rounded(existing.frame).size
                )
            }
            existing.retarget(to: target, sizing: sizing)
            animations[display, default: [:]][window] = existing
        } else {
            onAnimationStart(window)
            if isNewWindow {
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

    /// Clears per-window bookkeeping caches.
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
            let driver = DisplayLinkDriver(
                screen: screen
            ) { [weak self] dt in
                self?.tick(display: display, dt: dt)
            }
            // Route driver warnings to engine's sink (#1084).
            driver.onLog = { [weak self] in self?.onLog($0) }
            drivers[display] = driver
        }
        drivers[display]?.start()
    }
}
