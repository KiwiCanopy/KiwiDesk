import Foundation

extension KiwiCore {
    /// Where an open key sequence stands, nil once it closes
    /// (#1871): the hint panel's one input. One slot: the app
    /// assigns it once.
    public var onKeySequence: @MainActor (KeySequenceProgress?) -> Void {
        get { keys.onSequenceProgress }
        set { keys.onSequenceProgress = newValue }
    }

    /// A scroll key while a sequence is open (#3175): the hint
    /// panel's one scroll input. One slot: the app assigns it once.
    public var onKeySequenceScroll: @MainActor (KeySequenceScroll) -> Void {
        get { keys.onSequenceScroll }
        set { keys.onSequenceScroll = newValue }
    }

    /// The macOS shortcut a step key on `combo` takes from macOS
    /// while its sequence is open (#3173): one the router would
    /// pass, read as the router reads it. Nil for none, and for an
    /// app's menu chord, which an open sequence swallows anyway.
    public func sequenceStepTakes(_ combo: String) -> SystemShortcut? {
        guard let key = KeyCombo.parse(combo),
            let shortcut = SystemShortcuts.answering(
                key,
                in: keys.systemChords()
            ),
            shortcut.sequenceTier != .swallowed
        else { return nil }
        return shortcut
    }

    /// The tree the running sequence on `leader` answers, in the
    /// active layer: what the hint panel draws where the installed
    /// snapshot does not hold it, a Lua sequence whose end key read
    /// back nothing (#1871). An end key Lua defined carries no Lua.
    public func runningKeySequence(leader: String) -> KeyBinding? {
        keys.sequences(for: keys.currentLayer)
            .first { $0.stored == leader }?.pruned
    }

    /// Closes an open key sequence: a click or a Space switch ends
    /// one (#1871 ▸ hint panel).
    public func closeKeySequence() {
        keys.closeSequence()
    }
}
