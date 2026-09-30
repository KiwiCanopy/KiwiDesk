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
            // What it makes, said where it is chosen (#1790) — and
            // with no arrangement live nothing is temporary.
            subtitle: liveHome == nil
                ? nil : L("bar.menu.new_space.temporary", "temporary")
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

    /// With no tiled or floating window in it, so `delete_space`
    /// never rehomes one the user sees; a hidden one comes back as
    /// a new window would. A temporary Space goes at once; a
    /// profile Space asks first and leaves the file too; a Space
    /// another source declares goes for the session and says it
    /// comes back (#1790). A greyed row says why.
    private func deleteSpaceRow(_ id: SpaceID) -> BarMenuRow {
        let returns = returnsSubtitle(of: id)
        let block = spaceDeleteBlock(id)
        return .action(
            L("bar.menu.delete_space", "Delete Space"),
            enabled: block == nil,
            subtitle: block.map(blockSubtitle) ?? returns
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

    /// Why the bar's Delete is greyed, or nil where it may go: a
    /// held Space is its profile's (#1507), a tiled or floating
    /// window is one the user sees, and a screen's last Space the
    /// #1175 heal would re-mint the moment it went (#1790).
    func spaceDeleteBlock(_ id: SpaceID) -> SpaceDeleteBlock? {
        guard let space = state.workspaces[id] else { return .gone }
        if let origin = state.heldSpaces[id] {
            return .held(profile: origin.arrangement?.profileName)
        }
        guard space.windows.isEmpty else { return .hasWindows }
        let screen = state.workspaces.display(of: id)
        let sibling = state.workspaces.allSpaces.contains {
            $0.id != id && state.workspaces.display(of: $0.id) == screen
        }
        return sibling ? nil : .onlySpaceOnScreen
    }

    func spaceIsDeletable(_ id: SpaceID) -> Bool {
        spaceDeleteBlock(id) == nil
    }

    private func blockSubtitle(_ block: SpaceDeleteBlock) -> String? {
        switch block {
        case .gone: return nil
        case .hasWindows:
            return L("bar.menu.delete_space.has_windows", "Still has windows")
        case .onlySpaceOnScreen:
            return L(
                "bar.menu.delete_space.only_space",
                "The only Space on this screen"
            )
        case .held(let profile?):
            return L(
                "bar.menu.delete_space.held",
                "Goes back to %1$@",
                profile
            )
        case .held(nil):
            return L(
                "bar.menu.delete_space.held_standard",
                "Goes back when its setup returns"
            )
        }
    }
}

/// Why a Space chip's Delete is greyed (#1790).
enum SpaceDeleteBlock: Equatable {
    case gone, hasWindows, onlySpaceOnScreen
    case held(profile: String?)
}
