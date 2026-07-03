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
    public let profiles: ProfileManager
    public let crash: CrashRecovery
    public internal(set) var lua: LuaInterpreter?

    /// A stack z-order restore is waiting for the current
    /// animations to settle (see restoreStackZOrder).
    var pendingStackZOrderRestore = false

    /// `monitor_fallback` from init.lua (per-monitor chains).
    public var monitorFallback: [String: [String]] = [:]
    /// `space_monitor_map` from init.lua (per-space chains,
    /// beats per-monitor rules).
    public var spaceMonitorMap: [SpaceID: [String]] = [:]

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
        drag.isAnimating = { [weak self] id in
            guard let self else { return false }
            // Covers in-flight animations AND the trailing AX
            // echoes of frames we already applied: those
            // arrive after the animation settles and must not
            // read as user drags.
            return self.tiler.animation.isAnimating(window: id)
                || self.tiler.didRecentlySetFrame(id)
        }
        drag.onDragEnd = { [weak self] id, frame in
            self?.handleDragEnd(id, frame: frame)
        }
        tiler.animation.onAllAnimationsEnded = { [weak self] in
            self?.runPendingStackZOrderRestore()
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

    // MARK: - Lifecycle

    /// Loads the config and starts window management.
    public func start() {
        loadConfig()
        sleepWake.start()
        eventLoop.start()
        crash.start()
        do {
            try socket.start()
        } catch {
            onLog("socket server failed: \(error)")
        }
    }

    public func stop() {
        eventLoop.stop()
        sleepWake.stop()
        socket.stop()
        crash.shutdownCleanly()
    }

    public func retile() {
        tiler.retile(state: state)
    }

    // MARK: - Event flow

    private func handle(_ event: KiwiEvent) {
        // Closing or minimizing the focused window must hand
        // focus to the space's fallback window (state already
        // picks one; the AX raise below makes it real).
        var focusLost = false
        if case .windowDestroyed(let id) = event {
            focusLost = activeSpace?.focused == id
        }
        state.apply(event)
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            handleMonitorChange()
            emitMonitorChange()
        case .windowFocused(let id):
            emitFocusChange(id)
            if activeSpace?.mode.isFocusDriven == true {
                retile()
            }
        case .windowMoved(let id, let frame):
            drag.windowMoved(id, frame: frame)
        case .windowDestroyed(let id):
            drag.cancel(id)
        default:
            break
        }
        if TilingEngine.shouldRetile(after: event) {
            retile()
        }
        if focusLost, let next = activeSpace?.focused {
            focusWindow(next)
        }
    }

    /// Re-applies window frames after wake/unlock. Goes
    /// through the tiler's frame pipeline so the resulting AX
    /// echoes are not mistaken for user drags.
    private func restore(_ snapshot: StateSnapshot) {
        for record in snapshot.windows {
            tiler.setFrame(record.windowID, record.frame)
        }
    }

    // MARK: - Event emission helpers

    func emitSpaceChange() {
        guard let id = state.workspaces.activeSpace,
            let space = state.workspaces[id]
        else { return }
        bus.emit(
            .spaceChange,
            data: .object([
                "space_id": .string(id.raw),
                "layout_mode": .string(space.mode.rawValue),
                "window_count": .number(
                    Double(space.windows.count)
                ),
            ]),
            luaArgs: [
                .string(id.raw),
                .string(space.mode.rawValue),
            ]
        )
    }

    func emitLayoutChange(space: Space) {
        bus.emit(
            .layoutChange,
            data: .object([
                "space_id": .string(space.id.raw),
                "layout_mode": .string(space.mode.rawValue),
            ]),
            luaArgs: [
                .string(space.id.raw),
                .string(space.mode.rawValue),
            ]
        )
    }

    private func emitFocusChange(_ id: WindowID) {
        let window = state.windows[id]
        bus.emit(
            .focusChange,
            data: .object([
                "window_id": .number(Double(id.raw)),
                "app": .string(window?.appName ?? ""),
                "title": .string(window?.title ?? ""),
            ]),
            luaArgs: [
                .number(Double(id.raw)),
                .string(window?.appName ?? ""),
            ]
        )
    }

    private func emitMonitorChange() {
        let displays = state.workspaces.allDisplays
        bus.emit(
            .monitorChange,
            data: .object([
                "count": .number(Double(displays.count))
            ]),
            luaArgs: [.number(Double(displays.count))]
        )
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
