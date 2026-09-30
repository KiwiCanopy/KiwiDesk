import Foundation

/// A Space chip's New Space and Delete Space rows (#1790, the
/// owner's ruling of 2026-09-29 in its body), through the public
/// `create_space`, `pin_space_to_display` and `delete_space`.
extension KiwiCore {
    func spaceLifecycleRows(_ id: SpaceID) -> [BarMenuRow] {
        [newSpaceRow(beside: id), deleteSpaceRow(id)]
    }

    /// The next free number, pinned to the chip's screen so it
    /// lands where the user clicked. The number is taken at the
    /// click, never at the menu's build.
    private func newSpaceRow(beside id: SpaceID) -> BarMenuRow {
        let screen = state.workspaces.display(of: id).flatMap { shown in
            state.workspaces.allDisplays.first { $0.id == shown }
        }
        return .action(
            L("bar.menu.new_space", "New Space"),
            enabled: screen != nil
        ) { [weak self] in
            guard let self, let screen else { return }
            let space = freeSpaceNumber()
            execute("create_space", args: [.string(space.raw)])
            execute(
                "pin_space_to_display",
                args: [.string(space.raw), .string(screen.fingerprint)]
            )
        }
    }

    /// Empty only, so `delete_space` never rehomes a window (#1790).
    /// A Space a source declares returns on the next load, which
    /// the row says, as the Layout rows say "not saved".
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

    /// No member, no window away on another Desktop still filed
    /// there (#1146), not held (#1507), and not the only Space.
    func spaceIsDeletable(_ id: SpaceID) -> Bool {
        guard let space = state.workspaces[id] else { return false }
        return space.windows.isEmpty
            && !state.awayWindows.keys.contains {
                state.rememberedSpace(of: $0) == id
            }
            && state.heldSpaces[id] == nil
            && state.workspaces.allSpaces.count > 1
    }

    /// The smallest number no live Space takes and no remembered
    /// window names, so a returning window never lands in it.
    func freeSpaceNumber() -> SpaceID {
        SpaceID.smallestFreeNumber(
            among: state.workspaces.allSpaces.map(\.id)
                + state.rememberedSpaces.values.map(\.space)
        )
    }

    /// Whether the live Space set differs from the one the active
    /// profile declares — read from adoption state (#1245) — so a
    /// New or Delete arms Keep as a mode change does.
    func spaceSetDrifted() -> Bool {
        guard let active = profiles.active else { return false }
        return Set(capturedSpaces.map(\.id)) != active.declaredSpaces
    }
}
