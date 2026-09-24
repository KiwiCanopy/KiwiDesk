import Foundation

extension KiwiCore {
    /// Drops the space `StateCoordinator.init` seeded unasked
    /// when the first config load declared other Spaces but not
    /// it (#1526). Kept, it was a Space nobody made: every boot
    /// re-added a `1` after the user renamed theirs away, and a
    /// later mirror or save wrote it into their files. Rules
    /// once — a reload never touches a `1` the user owns.
    func retirePlaceholderSpace() {
        guard let placeholder = state.placeholderSpace else {
            return
        }
        state.placeholderSpace = nil
        let declared = state.workspaces.referenced
        guard !declared.contains(placeholder),
            state.workspaces[placeholder]?.windows.isEmpty ?? false,
            let survivor = state.workspaces.order.first(where: {
                $0 != placeholder
            })
        else { return }
        forwardWindows(of: placeholder, to: survivor)
        onLog(
            "boot: dropped undeclared placeholder space "
                + placeholder.raw
        )
    }
}
