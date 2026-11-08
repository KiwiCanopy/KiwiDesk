import Foundation

extension KiwiCore {
    /// Where an open key sequence stands, nil once it closes
    /// (#1871): the hint panel's one input. One slot: the app
    /// assigns it once.
    public var onKeySequence: @MainActor (KeySequenceProgress?) -> Void {
        get { keys.onSequenceProgress }
        set { keys.onSequenceProgress = newValue }
    }

    /// Closes an open key sequence: a click or a Space switch ends
    /// one (#1871 ▸ hint panel).
    public func closeKeySequence() {
        keys.closeSequence()
    }
}
