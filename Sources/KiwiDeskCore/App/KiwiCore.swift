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
    public internal(set) var lua: LuaInterpreter?

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
    }

    public func retile() {
        tiler.retile(state: state)
    }

    // MARK: - Event flow

    private func handle(_ event: KiwiEvent) {
        state.apply(event)
        switch event {
        case .displaysChanged:
            tiler.displaysChanged()
            emitMonitorChange()
        case .windowFocused(let id):
            emitFocusChange(id)
        default:
            break
        }
        if TilingEngine.shouldRetile(after: event) {
            retile()
        }
    }

    /// Re-applies window frames after wake/unlock.
    private func restore(_ snapshot: StateSnapshot) {
        for record in snapshot.windows {
            guard
                let element = eventLoop.element(
                    for: record.windowID
                )
            else { continue }
            WindowControl.setFrame(record.frame, of: element)
        }
    }

    // MARK: - Config

    /// Loads (or reloads) init.lua into a fresh VM.
    public func loadConfig() {
        bus.resetLuaCallbacks()
        guard let fresh = LuaInterpreter() else {
            onLog("failed to create Lua VM")
            return
        }
        lua = fresh
        bus.lua = fresh
        registerLuaAPI(on: fresh)

        ensureDefaultConfig()
        if case .failure(let error) = fresh.runFile(configURL) {
            onLog("init.lua error: \(error)")
        }
        applyConfigGlobals(from: fresh)
        retile()
    }

    /// Applies declarative globals after the config ran.
    private func applyConfigGlobals(from lua: LuaInterpreter) {
        if case .array(let rules) = lua.global("float_rules") {
            eventLoop.floatRules = FloatRules(
                rules.compactMap(\.stringValue)
            )
        }
        if case .table(let rules) = lua.global("app_rules") {
            var mapped: [String: SpaceID] = [:]
            for (app, value) in rules {
                if let space = value.stringValue {
                    mapped[app] = SpaceID(space)
                } else if let number = value.intValue {
                    mapped[app] = SpaceID(number)
                }
            }
            state.appRules = mapped
        }
    }

    /// Writes a starter init.lua on first launch.
    private func ensureDefaultConfig() {
        let files = FileManager.default
        guard !files.fileExists(atPath: configURL.path) else {
            return
        }
        try? files.createDirectory(
            at: configDirectory,
            withIntermediateDirectories: true
        )
        let template = """
            -- KiwiDesk configuration
            -- Docs: https://github.com/hajiboy95/KiwiDesk

            KiwiDesk.set_gap_global(10)

            -- Layout per space: bsp | stack | scrolling |
            -- monocle | grid | floating
            -- KiwiDesk.set_mode(1, "bsp")

            -- Windows that should never be tiled:
            -- float_rules = { "Calculator", "Finder:Get Info" }

            -- Send apps to fixed spaces:
            -- app_rules = { ["Spotify"] = "music" }
            """
        try? template.write(
            to: configURL,
            atomically: true,
            encoding: .utf8
        )
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
