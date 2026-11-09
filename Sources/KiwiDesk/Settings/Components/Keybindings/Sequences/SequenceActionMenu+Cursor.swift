import KiwiDeskCore
import SwiftUI

/// The action picker's one cursor (`DropdownCursor`): over the
/// pinned "Opens more keys ›", the commands the search left and the
/// pinned "Lua…", in that order.
extension SequenceActionMenu {
    /// The catalogue groups narrowed to the query's matches.
    var shownGroups: [SequenceActionCatalog.Group] {
        catalog.matching(search)
    }

    /// Every row the cursor stops on, top to bottom.
    static func sequence(
        _ groups: [SequenceActionCatalog.Group]
    ) -> [SequencePickSlot] {
        [.branch]
            + groups.flatMap(\.commands).map { .command($0.lua) }
            + [.lua]
    }

    /// The popover opens on the current pick, else the first command.
    func opened() {
        let current = catalog.command(running: node.lua).map {
            SequencePickSlot.command($0.lua)
        }
        let start = current ?? firstCommand(shownGroups)
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
                in: Self.sequence(groups),
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
                in: Self.sequence(groups),
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
        case .branch:
            request = nil
            onBranch()
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
        case .branch: return Self.branchLabel
        case .lua: return Self.luaLabel
        case .command(let lua):
            return catalog.command(running: lua)?.resolvedLabel ?? lua
        }
    }
}
