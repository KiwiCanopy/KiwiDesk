import Foundation

extension KiwiCore {
    /// Where an open key sequence stands, nil once it closes
    /// (#1871): the hint panel's one input. One slot: the app
    /// assigns it once.
    public var onKeySequence: @MainActor (KeySequenceProgress?) -> Void {
        get { keys.onSequenceProgress }
        set { keys.onSequenceProgress = newValue }
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
