import AppKit

/// What a Space Bar slot knows about one member (#1146): a
/// window on a Desktop nobody shows draws under its Space by the
/// rank it will return in, with the same glyph as a present one,
/// so the slot builder in `KiwiCore+SpaceBarItems.swift` reads
/// the visible state and the away ledger through ONE resolver.
extension KiwiCore {
    /// What a bar slot needs to know about one member, from the
    /// visible state or the away ledger — never both.
    struct SpaceBarMember {
        let id: WindowID
        let appName: String
        let pid: pid_t
        let isFloating: Bool
        let stickyScope: StickyScope
        let isTransientOverlay: Bool

        var isSticky: Bool { stickyScope != .none }
    }

    func spaceBarMember(_ id: WindowID) -> SpaceBarMember? {
        if let window = state.windows[id] {
            return SpaceBarMember(
                id: id,
                appName: window.appName,
                pid: window.pid,
                isFloating: window.isFloating,
                stickyScope: window.stickyScope,
                isTransientOverlay: window.isTransientOverlay
            )
        }
        guard let away = state.awayWindows[id] else { return nil }
        // A carried sticky is present, never away; a float
        // verdict is re-learned at the return.
        return SpaceBarMember(
            id: id,
            appName: away.appName,
            pid: away.pid,
            isFloating: false,
            stickyScope: .none,
            isTransientOverlay: false
        )
    }
}
