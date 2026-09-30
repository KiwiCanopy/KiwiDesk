import Foundation

/// A Space chip's New Space and Delete Space rows (#1790), through
/// the public `create_space`, `pin_space_to_display` and
/// `delete_space`. A New Space is temporary; the ruling is on the
/// issue and in `docs/design-decisions.md`.
extension KiwiCore {
    func spaceLifecycleRows(_ id: SpaceID) -> [BarMenuRow] {
        [newSpaceRow(beside: id), deleteSpaceRow(id)]
    }

    /// The next minted number, pinned to the chip's screen so it
    /// lands where the user clicked, and given its ⌃⌥N as a held
    /// Space is. Number and screen are read at the click; a screen
    /// gone since the menu opened mints nothing.
    private func newSpaceRow(beside id: SpaceID) -> BarMenuRow {
        .action(
            L("bar.menu.new_space", "New Space"),
            enabled: chipScreen(of: id) != nil,
            // What it makes, said where it is chosen (#1790).
            subtitle: L("bar.menu.new_space.temporary", "temporary")
        ) { [weak self] in
            guard let self, let screen = chipScreen(of: id) else { return }
            let space = mintedSpaceNumber()
            execute("create_space", args: [.string(space.raw)])
            execute(
                "pin_space_to_display",
                args: [.string(space.raw), .string(screen.fingerprint)]
            )
            topUpDigitShortcuts()
        }
    }

    private func chipScreen(of id: SpaceID) -> Display? {
        state.workspaces.display(of: id).flatMap { shown in
            state.workspaces.allDisplays.first { $0.id == shown }
        }
    }

    /// Empty only, so `delete_space` never rehomes a window. A
    /// temporary Space goes at once; a profile Space asks first and
    /// leaves the file too; a Space another source declares goes
    /// for the session and says it comes back (#1790).
    private func deleteSpaceRow(_ id: SpaceID) -> BarMenuRow {
        let returns = returnsSubtitle(of: id)
        return .action(
            L("bar.menu.delete_space", "Delete Space"),
            enabled: spaceIsDeletable(id),
            subtitle: returns
        ) { [weak self] in
            self?.deleteFromChip(id, comesBack: returns != nil)
        }
    }

    /// What re-creates a deleted `id` at the next reload, named —
    /// `init.lua` first, since that is the one the user edits — or
    /// nil where nothing does but the profile, whose Delete asks.
    private func returnsSubtitle(of id: SpaceID) -> String? {
        if initDeclaredSpaces.contains(id) {
            return L(
                "bar.menu.delete_space.returns_init",
                "init.lua brings it back on reload"
            )
        }
        guard profiles.standard?.spaces.contains(id) == true else {
            return nil
        }
        return L(
            "bar.menu.delete_space.returns_standard",
            "the built-in layout brings it back on reload"
        )
    }

    private func deleteFromChip(_ id: SpaceID, comesBack: Bool) {
        guard !comesBack, let profile = profiles.currentName,
            profiles.active?.declaredSpaces.contains(id) == true
        else {
            execute("delete_space", args: [.string(id.raw)])
            return
        }
        let question = SpaceDeleteQuestion(
            space: id,
            profile: profile,
            carriesOverrides: carriesOverrides(id)
        )
        barMenuHooks.confirmSpaceDelete(question) { [weak self] in
            // A window may have arrived while the alert was up.
            guard let self, spaceIsDeletable(id) else { return }
            execute(
                "delete_space",
                args: [.string(id.raw), .string(SpaceScope.profile.rawValue)]
            )
        }
    }

    /// Whether deleting `id` also drops a pin, a role or per-Space
    /// settings — `GuiConfig.carriesOverrides`' question, of live.
    private func carriesOverrides(_ id: SpaceID) -> Bool {
        var probe = tiler.settings
        probe.removeSpace(id)
        return spacePins[id] != nil || mainSpaces.contains(id)
            || fallbackSpace == id || probe != tiler.settings
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
}
