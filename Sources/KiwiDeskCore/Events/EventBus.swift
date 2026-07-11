import Foundation

/// Events external tools can subscribe to (SketchyBar,
/// JankyBorders, Hammerspoon) via socket or Lua callbacks.
public enum KiwiNotification: String, CaseIterable, Sendable,
    Codable
{
    case spaceChange = "space_change"
    case layoutChange = "layout_change"
    case focusChange = "focus_change"
    case monitorChange = "monitor_change"
    case nativeSpaceChange = "native_space_change"
    // Lifecycle events carry a `reason` (#40): created =
    // new | returned | restored, destroyed = closed |
    // minimized | vanished. The old `window_minimized` event
    // was retired into `reason: minimized` (pre-release, no
    // compat alias per AGENTS §5).
    case windowCreated = "window_created"
    case windowDestroyed = "window_destroyed"
    case windowMovedToSpace = "window_moved_to_space"
}

/// Fans events out to Lua callbacks and generic sinks (the
/// socket server registers one sink per subscriber).
///
/// Per the sandbox rules, a Lua callback that errors or times
/// out is logged and disabled — one bad callback never breaks
/// the event stream.
@MainActor
public final class EventBus {
    public typealias Sink =
        @MainActor (KiwiNotification, JSONValue) -> Void

    public var lua: LuaInterpreter?
    public var onLog: @MainActor (String) -> Void = { message in
        NSLog("KiwiDesk: %@", message)
    }

    private var luaCallbacks: [KiwiNotification: [Int32]] = [:]
    private var sinks: [UUID: Sink] = [:]

    public init() {}

    // MARK: - Subscriptions

    /// Registers a Lua callback (`KiwiDesk.on(event, fn)`).
    public func on(_ event: KiwiNotification, ref: Int32) {
        luaCallbacks[event, default: []].append(ref)
    }

    /// Registers a generic sink; returns a token for removal.
    @discardableResult
    public func addSink(_ sink: @escaping Sink) -> UUID {
        let token = UUID()
        sinks[token] = sink
        return token
    }

    public func removeSink(_ token: UUID) {
        sinks[token] = nil
    }

    /// Drops all Lua callbacks (config reload).
    public func resetLuaCallbacks() {
        if let lua {
            for refs in luaCallbacks.values {
                for ref in refs {
                    lua.release(ref: ref)
                }
            }
        }
        luaCallbacks = [:]
    }

    // MARK: - Emission

    /// Notifies sinks (JSON payload) and Lua callbacks
    /// (positional arguments, e.g. `(space_id, mode)`).
    public func emit(
        _ event: KiwiNotification,
        data: JSONValue,
        luaArgs: [LuaValue]
    ) {
        for sink in sinks.values {
            sink(event, data)
        }
        guard let lua,
            let refs = luaCallbacks[event],
            !refs.isEmpty
        else { return }

        var surviving: [Int32] = []
        for ref in refs {
            switch lua.call(ref: ref, args: luaArgs) {
            case .success:
                surviving.append(ref)
            case .failure(let error):
                onLog(
                    "Lua '\(event.rawValue)' callback "
                        + "disabled: \(error)"
                )
                lua.release(ref: ref)
            }
        }
        luaCallbacks[event] = surviving
    }
}
