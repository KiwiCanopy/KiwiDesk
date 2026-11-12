import KiwiDeskCore
import SwiftUI

/// The action picker's one cursor (`DropdownCursor`): over the
/// pinned entries, the commands the search left and the pinned
/// "App…" and "Lua…", in that order — the pinned entries alone where
/// the picker offers no catalogue.
extension SequenceActionMenu {
    /// The catalogue groups narrowed to the query's matches.
    var shownGroups: [SequenceActionCatalog.Group] {
        catalog.matching(search)
    }

    /// Every row the cursor stops on, top to bottom.
    func sequence(
        _ groups: [SequenceActionCatalog.Group]
    ) -> [SequencePickSlot] {
        Self.sequence(
            groups,
            pinned: pins.map(\.id),
            catalogue: showsCatalogue
        )
    }

    /// The rows for pinned ids `pinned` over `groups`, the catalogue
    /// and its App… and Lua… only where `catalogue` offers them.
    static func sequence(
        _ groups: [SequenceActionCatalog.Group],
        pinned: [String],
        catalogue: Bool
    ) -> [SequencePickSlot] {
        let top = pinned.map { SequencePickSlot.pinned($0) }
        guard catalogue else { return top }
        return top
            + groups.flatMap(\.commands).map { .command($0.lua) }
            + [.app, .lua]
    }

    /// The popover opens on the current pick, else the first command.
    func opened() {
        let pinnedPick = pins.first(where: \.picked).map {
            SequencePickSlot.pinned($0.id)
        }
        let current = catalog.command(running: face.lua).map {
            SequencePickSlot.command($0.lua)
        }
        let start =
            pinnedPick ?? current
            ?? (showsCatalogue
                ? firstCommand(shownGroups)
                : pins.first.map { .pinned($0.id) })
        cursor.opened(at: start, pointer: DropdownPointer.live())
        scrollTarget = start
    }

    func firstCommand(
        _ groups: [SequenceActionCatalog.Group]
    ) -> SequencePickSlot? {
        groups.first?.commands.first.map { .command($0.lua) }
    }

    func hover(_ slot: SequencePickSlot) {
        cursor.hover(slot, pointer: DropdownPointer.live())
    }

    /// A query edit hands the cursor to the keyboard, on the first
    /// match.
    func searched() {
        let first = firstCommand(shownGroups)
        cursor.reset(to: first, pointer: DropdownPointer.live())
        scrollTarget = first
    }

    func move(
        _ step: Int,
        in groups: [SequenceActionCatalog.Group]
    ) -> KeyPress.Result {
        guard
            let slot = cursor.keyMove(
                step,
                in: sequence(groups),
                pointer: DropdownPointer.live()
            )
        else { return .handled }
        scrollTarget = slot
        // Focus stays in the search field, so VoiceOver hears the
        // cursor only if it is said.
        AccessibilityNotification.Announcement(name(of: slot)).post()
        return .handled
    }

    /// Return picks the cursor's row.
    func commit(_ groups: [SequenceActionCatalog.Group]) {
        guard
            let slot = cursor.commit(
                in: sequence(groups),
                pointer: DropdownPointer.live()
            )
        else { return }
        take(slot, in: groups)
    }

    func take(
        _ slot: SequencePickSlot,
        in groups: [SequenceActionCatalog.Group]
    ) {
        switch slot {
        case .pinned(let id):
            request = nil
            pins.first { $0.id == id }?.action()
        case .app:
            request = nil
            // The app list opens once this popover has gone.
            DispatchQueue.main.async { onApp() }
        case .lua:
            request = nil
            // The editor opens once this popover has gone.
            DispatchQueue.main.async { onLua() }
        case .command(let lua):
            guard
                let command = groups.flatMap(\.commands).first(where: {
                    $0.lua == lua
                })
            else { return }
            pick(command)
        }
    }

    func pick(_ command: NavCommand) {
        request = nil
        onPick(command)
    }

    private func name(of slot: SequencePickSlot) -> String {
        switch slot {
        case .pinned(let id):
            return pins.first { $0.id == id }?.label ?? id
        case .app: return Self.appLabel
        case .lua: return Self.luaLabel
        case .command(let lua):
            return catalog.command(running: lua)?.resolvedLabel ?? lua
        }
    }
}
