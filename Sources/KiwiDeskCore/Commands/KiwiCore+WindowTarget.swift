import Foundation

/// A focused-window verb that may name its window instead (#1518,
/// the owner's 2026-09-29 ruling): the optional `.window` argument,
/// an id `get_state` reports. Where it sits is read off the verb's
/// record, so the decoder and the #292 preflight ask the one copy
/// the catalogue states — and a handler whose record takes one
/// reads it only through `commandTarget` (`WindowArgumentReachTests`).
extension APIReference {
    /// The position of `command`'s window argument, nil for a verb
    /// that takes none.
    static func windowArgumentIndex(_ command: String) -> Int? {
        entry(named: command)?.record.arguments.firstIndex {
            $0.kind == .window
        }
    }
}

/// What a window-explicit verb acts on.
enum CommandTarget {
    case window(WindowID)
    case refused(CommandResponse)
}

extension KiwiCore {
    /// Whether a call acts on the implicit focused window: a
    /// focused verb naming no window. The #292 preflight and the
    /// #1391 owed-focus landing both ask this.
    func impliesFocus(_ command: String, _ args: [JSONValue]) -> Bool {
        FocusedCommandPolicy.isFocused(command)
            && !namesWindow(command, args)
    }

    /// Whether `args` name the window `command` acts on.
    func namesWindow(_ command: String, _ args: [JSONValue]) -> Bool {
        guard let index = APIReference.windowArgumentIndex(command),
            args.indices.contains(index)
        else { return false }
        return args[index] != .null
    }

    /// The window `command` acts on: the one `args` name, else the
    /// focused one. A verb whose record takes no window refuses
    /// rather than guess — only a window-capable handler calls
    /// this, so a miss is drift.
    func commandTarget(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandTarget {
        guard let index = APIReference.windowArgumentIndex(command)
        else {
            return .refused(.fail("\(command) takes no window argument"))
        }
        guard args.indices.contains(index), args[index] != .null else {
            guard let focused = focusedWindowID else {
                return .refused(.fail("no focused window"))
            }
            return .window(focused)
        }
        let value = args[index]
        guard let spelled = value.stringValue else {
            return .refused(.fail("expected window id"))
        }
        // `exactly:` refuses a fraction, a negative and the
        // out-of-range alike.
        guard let number = value.numberValue,
            let raw = UInt32(exactly: number),
            state.windows[WindowID(raw)] != nil
        else {
            return .refused(.fail("unknown window: \(spelled)"))
        }
        return .window(WindowID(raw))
    }
}
