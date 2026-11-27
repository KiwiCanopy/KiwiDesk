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
    /// the first screen report (#3647 ▸ lane 3): a config load runs
    /// with no screen known. A number or `N#id` is stored at once
    /// and never waits; a fingerprint, an area key or a name waits,
    /// since only the order at the first report gives it a number.
    /// A call outside a load answers as it always did. Every verb
    /// whose map is keyed by screen number takes it — the splits and
    /// the bars' per-screen values; `pin_space_to_display` holds any
    /// screen while none is known, its runtime pins being keyed by
    /// fingerprint.
    func holdsNumberedScreenArg(_ arg: JSONValue?) -> Bool {
        guard luaAreaSplits.isRecording,
            state.workspaces.allDisplays.isEmpty, let arg
        else { return false }
        if arg.intValue != nil { return false }
        guard let raw = arg.stringValue else { return false }
        return ScreenSlotKey(parsing: raw) == nil
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
