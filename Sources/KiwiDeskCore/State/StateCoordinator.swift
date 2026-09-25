import CoreGraphics
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

    /// The departed windows whose departure was a CLOSE (#1414,
    /// #1561): written by `rememberClosedDeparture` from the gone
    /// handler's own classification, consumed by the create fold,
    /// which drops the departed memory, the slot record and any
    /// restore filed over them and places the window as NEW — its
    /// app rule, else the active Space, with a new window's focus.
    /// A set, not a clock: its lifetime is `rememberedSpaces`'s.
    var closedDepartures: Set<WindowID> = []

    /// The snapshot frame of a restored window not yet tracked
    /// (#1362), beside its `.restored` Space above — the arrival
    /// fold consumes it once, since a later return is not the
    /// restore's to place. Shares that memory's lifetime and its
    /// #152 exposure; a new `restore` refiles the whole map.
    var restoredFrames: [WindowID: CGRect] = [:]

    /// The slot a departed window held (#1207): a return re-inserts
    /// by this rank, so a Desktop's row comes back in the order it
    /// left rather than in re-track order. Kept after the return so
    /// later arrivals rank against it; rewritten at each departure.
    /// ONE value with the track head-ness the return re-applies
    /// (#1387), so every ender and the re-key carry both or neither.
    var departedSlots: [WindowID: DepartedSlot] = [:]

    /// The ranks alone, the shape `Space.insert(_:rank:ranks:)`
    /// takes.
    var departedRanks: [WindowID: Int] {
        departedSlots.mapValues(\.rank)
    }

    /// Windows the compositor hosts on a Desktop nobody shows
    /// (#1146) — the away LEDGER, beside the visible-only state:
    /// written on a compositor-confirmed `vanished` and by the
    /// boot census, ended by the return, a census that no longer
    /// hosts the id, the app's exit, the #634 reset, and moved by
    /// a re-key. Its space and rank are the two records above.
    var awayWindows: [WindowID: AwayWindow] = [:]

    /// What each PROFILE's Spaces held when it was last live
    /// (#1230) — the record the three above cannot make, because
    /// a profile switch moves no window out of state. Reached
    /// only through `KiwiCore+ProfileSpaces.swift`; its enders
    /// are a profile deleted, a profile renamed, and #634.
    var profilePartitioning = ProfilePartitioning()

    /// Spaces carried onto a remaining screen when their own was
    /// unplugged (#1507), by live id — session state that no
    /// Keep, Save or partitioning record captures; written and
    /// ended in `KiwiCore+HeldSpaces.swift`.
    var heldSpaces: [SpaceID: HeldOrigin] = [:]
    /// Each Space's screen fingerprint as the first report of a
    /// screen-count change found it (#1507) — the one fact the
    /// report's own resolve erases for an unpinned Space. Written
    /// by the event arm, read by the hold, cleared by the settle.
    var settlingScreens: [SpaceID: String] = [:]

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

    /// The id a first launch seeds before any config declares one.
    public static let placeholderID = SpaceID(1)

    /// A seed planted unasked so state is never spaceless before a
    /// config loads — by `init`, and by the #634 reset for a
    /// Lua-owned config; nil once a load has ruled on it (#1526,
    /// `retirePlaceholderSpace`).
    var placeholderSpace: SpaceID?

    public init(defaultSpace: SpaceID = placeholderID) {
        workspaces.ensureSpace(defaultSpace)
        placeholderSpace = defaultSpace
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
        if closedDepartures.remove(old) != nil {
            closedDepartures.insert(new)
        }
        if let frame = restoredFrames.removeValue(forKey: old) {
            restoredFrames[new] = frame
        }
        if let slot = departedSlots.removeValue(forKey: old) {
            departedSlots[new] = slot
        }
        for (id, slot) in departedSlots where slot.handedTo == old {
            departedSlots[id]?.handedTo = new
        }
        if let away = awayWindows.removeValue(forKey: old) {
            awayWindows[new] = away.withID(new)
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
            // The app's exit ends its away entries for good
            // (#1146), and a head's hand-off with them (#1387).
            for entry in awayWindows.values where entry.pid == pid {
                forgetAway(entry.id)
            }

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
            rekey(old, to: new)

        case .displaysChanged(let displays):
            reconcile(displays: displays)

        case .desktopChanged:
            break
        }
        return effects
    }
}
