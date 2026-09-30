import Foundation

/// A Space chip's New Space and Delete Space rows (#1790, the
/// owner's ruling of 2026-09-29 in its body), through the public
/// `create_space`, `pin_space_to_display` and `delete_space`.
extension KiwiCore {
    func spaceLifecycleRows(_ id: SpaceID) -> [BarMenuRow] {
        [newSpaceRow(beside: id), deleteSpaceRow(id)]
    }

    /// The next minted number, pinned to the chip's screen so it
    /// lands where the user clicked. Number and screen are read at
    /// the click; a screen gone since the menu opened mints nothing.
    private func newSpaceRow(beside id: SpaceID) -> BarMenuRow {
        .action(
            L("bar.menu.new_space", "New Space"),
            enabled: chipScreen(of: id) != nil
        ) { [weak self] in
            guard let self, let screen = chipScreen(of: id) else { return }
            let space = mintedSpaceNumber()
            execute("create_space", args: [.string(space.raw)])
            execute(
                "pin_space_to_display",
                args: [.string(space.raw), .string(screen.fingerprint)]
            )
        }
    }

    private func chipScreen(of id: SpaceID) -> Display? {
        state.workspaces.display(of: id).flatMap { shown in
            state.workspaces.allDisplays.first { $0.id == shown }
        }
    }

    /// Empty only, so `delete_space` never rehomes a window (#1790).
    /// A Space a source declares returns when that source is next
    /// applied, which the row says, as the Layout rows say "not
    /// saved".
    private func deleteSpaceRow(_ id: SpaceID) -> BarMenuRow {
        .action(
            L("bar.menu.delete_space", "Delete Space"),
            enabled: spaceIsDeletable(id),
            subtitle: declaredSources(of: id).isEmpty
                ? nil
                : L("bar.menu.delete_space.returns", "comes back on reload")
        ) { [weak self] in
            _ = self?.execute("delete_space", args: [.string(id.raw)])
        }
    }

    /// Holds nothing (`spaceHoldsNothing`), is not held (#1507),
    /// and is not its screen's last Space, which the #1175 heal
    /// would re-mint the moment it went.
    func spaceIsDeletable(_ id: SpaceID) -> Bool {
        guard state.workspaces[id] != nil,
            spaceHoldsNothing(id),
            state.heldSpaces[id] == nil
        else { return false }
        let screen = state.workspaces.display(of: id)
        return state.workspaces.allSpaces.contains {
            $0.id != id && state.workspaces.display(of: $0.id) == screen
        }
    }

    /// Whether a Keep would change which Spaces the live profile
    /// lists: the live Space set a Keep writes against the list
    /// the last apply adopted (#1245). Pins are not compared, and
    /// a #1175 heal seed is the system's, not an edit, so it arms
    /// nothing. Both Keep rows — a chip's and the status item's —
    /// arm on it.
    public var spaceSetDrifted: Bool {
        guard let active = profiles.active else { return false }
        let live = Set(capturedSpaces.map(\.id))
            .subtracting(healedSpaces.values)
        return live != active.listedSpaces.subtracting(healedSpaces.values)
    }
}
