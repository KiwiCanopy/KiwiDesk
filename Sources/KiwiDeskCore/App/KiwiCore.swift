import AppKit
import Foundation

/// The application core: owns state, event loop, tiler, Lua,
/// and the event bus, and wires them together. The GUI layer
/// (AppDelegate) only handles permissions and windows.
@MainActor
public final class KiwiCore {
    public let eventLoop = EventLoop()
    public internal(set) var state = StateCoordinator()
    public let tiler = TilingEngine()
    public let sleepWake = SleepWakeManager()
    public let bus = EventBus()
    public let keys = KeybindingManager()
    public let drag = DragCoordinator()
    public let dragOverlay = DragOverlay()
    public let appBars = AppBarManager()
    public let mouse = MouseTracker()
    public let profiles: ProfileManager
    public let crash: CrashRecovery
    public internal(set) var lua: LuaInterpreter?
    public let exec = ExecLauncher()

    /// A stack z-order restore is waiting for the current
    /// animations to settle (see restoreStackZOrder).
    var pendingZOrderRestore = false

    /// Deferred switch to a hidden window's virtual space
    /// (see scheduleFocusFollow).
    var pendingFocusFollow: Task<Void, Never>?

    /// One-shot re-assertion of a virtual space's layout shortly
    /// after a switch, catching windows whose single frame-set a
    /// slow/background app dropped (see scheduleSpaceSettle).
    var pendingSpaceSettle: Task<Void, Never>?

    /// One-shot startup sweep re-tracking windows the cold
    /// AX scan missed (see start()).
    var pendingStartupSweep: Task<Void, Never>?

    /// Native desktop we are currently on (Mission Control
    /// number), and the virtual space each desktop showed
    /// last, restored when the user returns to it.
    var lastNativeSpace: Int?
    var virtualSpaceMemory: [Int: SpaceID] = [:]
    /// When the last native desktop switch happened; focus
    /// events during the transition must not change spaces.
    var lastNativeSwitch: Date = .distantPast

    /// The live arrangement's space→monitor fingerprint pins,
    /// adopted from the active profile's matching monitor set
    /// and edited by the GUI Canvas (#36). Internal: the GUI
    /// reads placement via `loadGuiConfig` and writes it via
    /// `applyProfileScopedState`, never directly.
    var spacePins: [SpaceID: String] = [:]
    /// Spaces assigned the *Main* role — they follow whatever
    /// display is currently main (#36).
    var mainSpaces: Set<SpaceID> = []
    /// Profile bound per native macOS Space, keyed by the
    /// Mission Control number (1-based). Populated by
    /// `bind_profile_to_native_space`.
    public internal(set) var nativeSpaceBindings: [Int: String] = [:]

    /// Log line consumer (GUI console later; syslog now).
    public var onLog: @MainActor (String) -> Void = { message in
        NSLog("KiwiDesk: %@", message)
    }

    /// `~/.config/KiwiDesk/` (created on demand).
    public let configDirectory: URL
    public var configURL: URL {
        configDirectory.appendingPathComponent("init.lua")
    }

    public let socket: SocketServer

    /// Where the CLI expects the running app's socket.
    public nonisolated static var defaultSocketPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                ".config/KiwiDesk/KiwiDesk.sock"
            ).path
    }

    public init(
        configDirectory: URL? = nil
    ) {
        let directory =
            configDirectory
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KiwiDesk")
        self.configDirectory = directory
        self.socket = SocketServer(
            path:
                directory
                .appendingPathComponent("KiwiDesk.sock").path
        )
        self.profiles = ProfileManager(
            directory: directory.appendingPathComponent(
                "profiles"
            )
        )
        self.crash = CrashRecovery(directory: directory)

        crash.captureState = { [weak self] in
            self?.state.snapshot()
        }
        crash.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        crash.onLog = { [weak self] message in
            self?.onLog(message)
        }
        keys.onLog = { [weak self] message in
            self?.onLog(message)
        }
        exec.onLog = { [weak self] message in
            self?.onLog(message)
        }
        profiles.onLog = { [weak self] message in
            self?.onLog(message)
        }
        wireDrag()
        appBars.onSelect = { [weak self] id in
            self?.focusWindow(id)
        }
        appBars.onMove = { [weak self] space, from, to in
            self?.moveBarItem(space: space, from: from, to: to)
        }
        tiler.animation.onAllAnimationsEnded = { [weak self] in
            self?.runPendingZOrderRestore()
        }

        socket.handler = { [weak self] command, args in
            self?.execute(command, args: args)
                ?? .fail("core unavailable")
        }
        socket.bus = bus
        tiler.elementProvider = { [weak self] id in
            self?.eventLoop.element(for: id)
        }
        eventLoop.onEvent = { [weak self] event in
            self?.handle(event)
        }
        sleepWake.captureState = { [weak self] in
            self?.state.snapshot()
        }
        sleepWake.restoreState = { [weak self] snapshot in
            self?.restore(snapshot)
        }
        bus.onLog = { [weak self] message in
            self?.onLog(message)
        }
    }

    /// `animated: nil` (the default for a bare `retile()`) means
    /// "a structural reflow" — window open/close, mode / gap /
    /// param change — and obeys `animations.on_relayout`. Callers
    /// that own a more specific trigger (space switch, swap,
    /// resize, focus slide) pass an explicit `animated:` and are
    /// gated by their own toggle instead.
    public func retile(
        animated: Bool? = nil,
        force: Bool = false,
        newlyCreatedWindow: WindowID? = nil
    ) {
        tiler.retile(
            state: state,
            animated: animated
                ?? tiler.settings.animations.onRelayout,
            force: force,
            newlyCreatedWindow: newlyCreatedWindow
        )
        updateAppBar()
    }

    // MARK: - Event flow

    private func handle(_ event: KiwiEvent) {
        // Closing or minimizing the focused window must hand
        // focus to the space's fallback window (state already
        // picks one; the AX raise below makes it real). The
        // gone-event payload needs the window's app and space
        // captured here too — state.apply removes both.
        var focusLost = false
        var goneApp: String? = nil
        var goneSpace: SpaceID? = nil
        if case .windowDestroyed(let id, _) = event {
            focusLost = activeSpace?.focused == id
            goneApp = state.windows[id]?.appName
            goneSpace = state.workspaces.space(of: id)
        }
        state.spawnPlacements = [
            .bsp: tiler.settings.bsp.newWindowPlacement,
            .stack: tiler.settings.stack.newWindowPlacement,
            .scrolling:
                tiler.settings.scrolling.newWindowPlacement,
            .grid: tiler.settings.grid.newWindowPlacement,
        ]
        state.spawnOverride = tiler.settings.placementOverride
        state.apply(event)
        var newlyCreatedWindow: WindowID? = nil
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
        case .windowFocused(let id):
            emitFocusChange(id)
            // cmd+tab (or a click) can reach a window hidden
            // in an inactive virtual space; pull that space
            // forward instead of typing into a stashed window.
            // Deferred: app activation transiently re-reports
            // the app's OLD focused window right before a new
            // window opens — only follow if focus settles.
            if let space = state.workspaces.space(of: id),
                space != state.workspaces.activeSpace
            {
                scheduleFocusFollow(id)
            } else if activeSpace?.mode.isFocusDriven == true {
                retile(animated: focusRetileAnimated)
            }
        case .windowCreated(let window):
            // A brand-new window supersedes a pending follow
            // of a hidden window (see above).
            pendingFocusFollow?.cancel()
            newlyCreatedWindow = window.id
            emitWindowCreated(window)
        case .windowMoved(let id, let frame):
            drag.windowMoved(id, frame: frame)
        case .windowResized(let id, let frame):
            // Resize gestures share the drag pipeline (same
            // settle debounce). Only mouse-driven resizes
            // count; apps resizing themselves are corrected
            // by the next retile. `validated` lets the
            // trailing events of a fast resize (classified
            // via the recent press near a slot edge) start
            // the gesture even after the release.
            if isResizeGesture(id) {
                drag.windowMoved(
                    id,
                    frame: frame,
                    validated: true
                )
            }
        case .windowDestroyed(let id, let wasMinimized):
            drag.cancel(id)
            dragOverlay.hideAll()
            if wasMinimized {
                emitWindowMinimized(
                    id,
                    app: goneApp,
                    space: goneSpace
                )
            } else {
                emitWindowDestroyed(
                    id,
                    app: goneApp,
                    space: goneSpace
                )
            }
        case .nativeSpaceChanged:
            handleNativeSpaceChange()
        default:
            break
        }
        if TilingEngine.shouldRetile(after: event) {
            retile(newlyCreatedWindow: newlyCreatedWindow)
        }
        // Only raise windows the app still lists: after a
        // native Space switch the fallback may live on the
        // previous desktop, and raising it would switch back.
        if focusLost, let next = activeSpace?.focused,
            eventLoop.isListed(next)
        {
            focusWindow(next)
        }
    }

    /// Re-applies a snapshot after wake/unlock, a crash, or a
    /// restart: space membership and order first (the array
    /// order is the layout order), then the raw frames. Frames
    /// go through the tiler's frame pipeline so the resulting
    /// AX echoes are not mistaken for user drags.
    func restore(_ snapshot: StateSnapshot) {
        state.adopt(snapshot)
        for record in snapshot.windows {
            tiler.setFrame(record.windowID, record.frame)
        }
        // Diagnostic: snapshot windows that are not tracked
        // yet stay out of their space until a reconcile finds
        // them (cold-AX startup scan, issue #21 follow-up).
        let missing = snapshot.windows.filter {
            state.windows[$0.windowID] == nil
        }.count
        if missing > 0 {
            onLog(
                "restore: \(missing) snapshot windows not "
                    + "tracked yet"
            )
        }
    }

    // MARK: - Accessors

    public var activeSpace: Space? {
        state.workspaces.activeSpace.flatMap {
            state.workspaces[$0]
        }
    }

    public var focusedWindow: ManagedWindow? {
        activeSpace?.focused.flatMap { state.windows[$0] }
    }
}
