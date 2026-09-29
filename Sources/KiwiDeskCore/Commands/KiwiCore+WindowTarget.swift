import Foundation

/// A focused-window verb that may name its window instead (#1518,
/// the owner's 2026-09-29 ruling): the optional trailing `window`
/// argument, an id `get_state` reports. Where it sits is read off
/// the verb's record, so the decoder and the #292 preflight ask
/// the one copy the catalogue states.
extension APIReference {
    /// The name every window-explicit verb gives the argument.
    static let windowArgument = "window"

    /// The position of `command`'s window argument, nil for a verb
    /// that takes none.
    static func windowArgumentIndex(_ command: String) -> Int? {
        entry(named: command)?.record.arguments.firstIndex {
            $0.name == windowArgument
        }
    }
}

/// What a window-explicit verb acts on.
enum CommandTarget {
    case window(WindowID)
    case refused(CommandResponse)
}

extension KiwiCore {
    /// Whether `args` name the window `command` acts on, which
    /// takes the call out of the #292 preflight: the target is
    /// named rather than implied by the foreground.
    func namesWindow(_ command: String, _ args: [JSONValue]) -> Bool {
        guard let index = APIReference.windowArgumentIndex(command),
            args.indices.contains(index)
        else { return false }
        return args[index] != .null
    }

    /// The window `command` acts on: the one `args` name, else the
    /// focused one.
    func commandTarget(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandTarget {
        guard namesWindow(command, args),
            let index = APIReference.windowArgumentIndex(command)
        else {
            guard let focused = focusedWindowID else {
                return .refused(.fail("no focused window"))
            }
            return .window(focused)
        }
        let value = args[index]
        guard let raw = value.intValue, let id = UInt32(exactly: raw),
            state.windows[WindowID(id)] != nil
        else {
            let spelled = value.stringValue ?? "\(value)"
            return .refused(.fail("unknown window: \(spelled)"))
        }
        return .window(WindowID(id))
    }
}
