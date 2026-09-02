import Foundation

/// Applies `KiwiEvent`s to the state managers (`WindowManager`,
/// `WorkspaceManager`). Pure and synchronous write path.
public struct StateCoordinator: Sendable {
    public internal(set) var windows = WindowManager()
    public internal(set) var workspaces = WorkspaceManager()

    /// `app_rules` routing new windows of these apps to a fixed space.
    public var appRules: [String: SpaceID] = [:]

    /// `new_window_placement` per layout mode, mirrored from tiler settings.
    public var spawnPlacements: [LayoutMode: SpawnPlacement] = [
        .bsp: BspParams().newWindowPlacement,
        .stack: StackParams().newWindowPlacement,
        .scrolling: ScrollingParams().newWindowPlacement,
        .grid: GridParams().newWindowPlacement,
    ]

    /// Per-space `new_window_placement_override`.
    public var spawnOverride: [SpaceID: SpawnPlacement] = [:]

    /// Track layout params (#128) governing new tiled track allocations.
    public var trackParams = TrackParams()

    /// Per-space fill-then-spill track capacity (#437), geometry-derived.
    public var trackCapacities: [SpaceID: Int] = [:]

    /// Physical display of an arriving window (#1010), consumed on create.
    public var arrivalDisplay: DisplayID?

    /// The window a Desktop return still owes its focus (#1207),
    /// mirrored in before each create like `arrivalDisplay`.
    public var returningFocus: WindowID?

    /// Last known space per window for native-Space restores.
    var rememberedSpaces: [WindowID: SpaceMemory] = [:]

    /// The slot a departed window held (#1207): a return re-inserts
    /// by this rank, so a Desktop's row comes back in the order it
    /// left rather than in re-track order. Kept after the return so
    /// later arrivals rank against it; rewritten at each departure.
    var departedSlots: [WindowID: Int] = [:]

    /// Minimized windows in order (#40, #673; `MinimizeOrderTests`).
    var minimizeOrder: [MinimizedWindow] = []

    /// Explicit `make_floating` / `make_tiled` verdicts per window.
    var manualFloatOverrides: [WindowID: Bool] = [:]

    /// Per-window `override_sticky_reach` verdicts (#1145): absent =
    /// the global `sticky.desktop_reach` toggle rules. Session
    /// state, dropped on destroy — old ids can be recycled.
    var stickyReachOverrides: [WindowID: Bool] = [:]

    /// Manual float intent remembered across close/reopen (#160).
    /// Keyed by app + title, not `WindowID`: a reopened window
    /// gets a fresh id, and old ids can be recycled onto unrelated
    /// windows. Last close wins, first reopen consumes.
    var rememberedFloating: [WindowIdentity: Bool] = [:]

    /// Sticky intent remembered across window close/reopen (#414, #445).
    var rememberedSticky: [WindowIdentity: StickyScope] = [:]

    /// Stable close/reopen identity of a window (#160).
    struct WindowIdentity: Hashable, Sendable {
        let app: String
        let title: String

        init(of window: ManagedWindow) {
            app = window.appName
            title = window.title
        }
    }

    public init(defaultSpace: SpaceID = SpaceID(1)) {
        workspaces.ensureSpace(defaultSpace)
    }

    /// Swaps a window ID across every ID-keyed map for native tab
    /// switches (#308) — the hand-mirrored list §5 warns about, so
    /// `WindowRekeyParityTests` discovers the containers by
    /// reflection. `minimizeOrder`'s element is a struct the
    /// reflection cannot see; the `String(describing:)` scan and
    /// `MinimizeOrderTests` are its nets (#673).
    /// `rememberedFloating` is keyed by app+title and deliberately
    /// untouched.
    mutating func rekey(_ old: WindowID, to new: WindowID) {
        windows.rekey(old, to: new)
        workspaces.rekey(old, to: new)
        if let space = rememberedSpaces.removeValue(forKey: old) {
            rememberedSpaces[new] = space
        }
        if let index = minimizeOrder.firstIndex(
            where: { $0.id == old }
        ) {
            minimizeOrder[index].id = new
        }
        if let intent = manualFloatOverrides.removeValue(
            forKey: old
        ) {
            manualFloatOverrides[new] = intent
        }
        if let reach = stickyReachOverrides.removeValue(
            forKey: old
        ) {
            stickyReachOverrides[new] = reach
        }
    }

    /// Folds an event into state and returns side-effect facts (#166).
    @discardableResult
    public mutating func apply(
        _ event: KiwiEvent
    ) -> AppliedEffects {
        var effects = AppliedEffects()
        switch event {
        case .appLaunched:
            break

        case .appTerminated(let pid):
            for window in windows.windows(pid: pid) {
                rememberFloatOverride(of: window)
                rememberStickyIntent(of: window)
            }
            for id in windows.removeAll(pid: pid) {
                workspaces.remove(id)
                stickyReachOverrides[id] = nil
            }
            forgetMinimized(pid: pid)

        case .windowCreated(let window):
            applyWindowCreated(window, effects: &effects)

        case .windowDestroyed(let id, let wasMinimized):
            applyWindowDestroyed(
                id,
                wasMinimized: wasMinimized,
                effects: &effects
            )
            // Only a genuine close drops the reach pin (#1145): a
            // minimize keeps its id and scope, and a hide — folded
            // below as a destroy — keeps its window.
            if !wasMinimized {
                stickyReachOverrides[id] = nil
            }

        // Hides fold as non-minimized destroys to remember space (#913).
        case .windowHidden(let id):
            applyWindowDestroyed(
                id,
                wasMinimized: false,
                effects: &effects
            )

        case .windowMoved(let id, let frame):
            windows.updateFrame(id, frame: frame)

        case .windowResized(let id, let frame):
            windows.updateFrame(id, frame: frame)

        case .windowFocused(let id):
            effects.focusBefore = workspaces.activeSpace
                .flatMap { workspaces[$0]?.focused }
            if let space = workspaces.space(of: id) {
                workspaces.focus(id, in: space)
            }

        case .windowTitleChanged(let id, let title):
            let floatBefore = windows[id]?.isFloating
            windows.updateTitle(id, title: title)
            // Retry lazy-title app overrides once real title lands (#160).
            if let window = windows[id] {
                restoreFloatOverride(of: window)
                restoreStickyIntent(of: window)
            }
            if let floatBefore,
                windows[id]?.isFloating != floatBefore
            {
                effects.floatFlipped = true
            }

        case .windowFloatChanged(let id, let floating):
            // Manual overrides beat AX detection on title flips (#160).
            guard manualFloatOverrides[id] == nil else { break }
            // Clears stale overlay flag on return to tiled (#300).
            windows.setFloating(id, floating)

        case .windowFullscreenChanged(let id, let fullscreen):
            windows.setFullscreen(id, fullscreen)

        case .windowRekeyed(let old, let new):
            if let slot = departedSlots.removeValue(forKey: old) {
                departedSlots[new] = slot
            }
            rekey(old, to: new)

        case .displaysChanged(let displays):
            reconcile(displays: displays)

        case .desktopChanged:
            break
        }
        return effects
    }
}
