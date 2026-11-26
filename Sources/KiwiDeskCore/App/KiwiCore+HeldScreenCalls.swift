import Foundation

/// A call that named a screen while none was known: a cold boot runs
/// `init.lua` before any screen is published (#3631, #3640). Held in
/// call order and replayed at the first report of a screen.
enum HeldScreenCall {
    /// `pin_space_to_display`'s Space and raw screen argument.
    case pin(SpaceID, JSONValue)
    /// A config load's settings write that waits on a screen: a split
    /// or a bar's per-screen value by number or name, or an area's
    /// name behind a held split. `split` marks one that writes
    /// `display_areas`.
    case settings(split: Bool, replay: @MainActor () -> CommandResponse)

    /// The Space a held pin names, nil for any other call.
    var pinnedSpace: SpaceID? {
        if case .pin(let space, _) = self { return space }
        return nil
    }

    /// Whether this is a settings write.
    var isSettings: Bool {
        if case .settings = self { return true }
        return false
    }

    /// Whether this is a write of `display_areas`.
    var isSplit: Bool {
        if case .settings(true, _) = self { return true }
        return false
    }
}

extension KiwiCore {
    /// Whether a settings write naming `arg` as its screen waits for
    /// the first screen report: a config load runs with no screen
    /// known, and the argument is a number or a name, which only a
    /// known screen resolves. A fingerprint or area key resolves
    /// without one and never waits; a call outside a load answers
    /// as it always did.
    func holdsScreenArg(_ arg: JSONValue?) -> Bool {
        guard luaAreaSplits.isRecording,
            state.workspaces.allDisplays.isEmpty, let arg
        else { return false }
        if arg.intValue != nil { return true }
        guard let raw = arg.stringValue else { return false }
        return !Self.isFingerprint(ScreenAreaKey(parsing: raw).fingerprint)
    }

    /// Holds a settings write until a screen is known; `replay` runs
    /// the verb's own body again at the drain. A split names no screen
    /// yet, so it is noted against the load's record only then.
    func holdSettingsCall(
        split: Bool,
        replay: @escaping @MainActor () -> CommandResponse
    ) {
        heldScreenCalls.append(.settings(split: split, replay: replay))
    }

    /// Replays every held call in the order it was made, at the first
    /// `.displaysChanged` that reports a screen and ahead of its one
    /// total resolve, so nothing places alone and leaves a screen to
    /// the heal (#3631). A refusal is logged as it would answer live.
    /// A report of no screen keeps the list, and the load's deferred
    /// split settle with it.
    func drainHeldScreenCalls() {
        guard !state.workspaces.allDisplays.isEmpty,
            !heldScreenCalls.isEmpty
        else { return }
        let held = heldScreenCalls
        heldScreenCalls = []
        for call in held {
            switch call {
            case .pin(let space, let arg):
                let reason = storeSpacePin([.string(space.raw), arg])
                    .response.error
                if let reason {
                    onLog("pin_space_to_display(\(space.raw)): \(reason)")
                }
            case .settings(_, let replay):
                luaAreaSplits.replaying = true
                let reason = replay().error
                luaAreaSplits.replaying = false
                if let reason { onLog("held screen call: \(reason)") }
            }
        }
        settleHeldLuaAreaSplits()
    }
}
