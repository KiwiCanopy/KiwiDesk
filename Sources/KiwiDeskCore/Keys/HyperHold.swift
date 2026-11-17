import os

/// Whether the Hyper key is held right now (#1870, #3407): the
/// one store of the Hyper layer's hold. The keybinding manager
/// writes it on the main actor; the scroll tap, the pointer tap
/// and the touch reader read it on their own threads when they
/// build a chord, since Hyper is no event flag.
public final class HyperHold: Sendable {
    private let held = OSAllocatedUnfairLock(initialState: false)

    public init() {}

    public var isHeld: Bool {
        get { held.withLock { $0 } }
        set { held.withLock { $0 = newValue } }
    }
}
