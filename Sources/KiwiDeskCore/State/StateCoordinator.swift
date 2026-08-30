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

    /// Last known space per window for native-Space restores.
    var rememberedSpaces: [WindowID: SpaceMemory] = [:]

    /// Minimized windows in order (#40, #673; `MinimizeOrderTests`).
    var minimizeOrder: [MinimizedWindow] = []

    /// Explicit `make_floating` / `make_tiled` verdicts per window.
    var manualFloatOverrides: [WindowID: Bool] = [:]

    /// Manual float intent remembered across window close/reopen (#160).
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

    /// Swaps a window ID across all ID-keyed maps for native tab switches
    /// (#308, #673; `WindowRekeyParityTests`, `MinimizeOrderTests`).
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
            rekey(old, to: new)

        case .displaysChanged(let displays):
            reconcile(displays: displays)

        case .desktopChanged:
            break
        }
        return effects
    }
}
