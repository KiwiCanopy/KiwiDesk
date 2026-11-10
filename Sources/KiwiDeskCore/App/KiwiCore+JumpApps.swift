import AppKit

/// KiwiHub's app strip (#3135): the apps the Windows side lists,
/// most recently used first, read with the rows when the panel
/// opens. An app's recency is its own activation or its windows'
/// latest focus, on one tick (`appRecencyRank`).
extension KiwiCore {
    /// Every app a row lists, ordered by recency, ties keeping the
    /// rows' order, with your app first, as ⌘⇥ lists the app in
    /// front (#3168). An app with no listed window has no tile: the
    /// strip never holds an app All does not.
    func jumpApps(
        for entries: [JumpEntry],
        first yours: JumpEntry? = nil
    ) -> [JumpApp] {
        let listed = JumpApp.listed(in: entries).enumerated()
        let ranked = listed.sorted { lhs, rhs in
            let left = state.appRecencyRank(of: lhs.element.pid)
            let right = state.appRecencyRank(of: rhs.element.pid)
            return left != right ? left > right : lhs.offset < rhs.offset
        }.map(\.element)
        guard let yours else { return ranked }
        return [JumpApp(pid: yours.pid, name: yours.app)]
            + ranked.filter { $0.pid != yours.pid }
    }

    /// The listed window with the newest focus stamp (#1840), nil
    /// where no listed window has one.
    func jumpLastUsed(in entries: [JumpEntry]) -> JumpEntry.Target? {
        entries.compactMap { entry -> (JumpEntry.Target, UInt64)? in
            guard case .window(let id) = entry.target else { return nil }
            let rank = state.focusRecencyRank(of: id)
            return rank > 0 ? (entry.target, rank) : nil
        }
        .max { $0.1 < $1.1 }?.0
    }
}
