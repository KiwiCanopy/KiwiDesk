import KiwiDeskCore

/// Each foldable catalog row's place (#2312), keyed by its Lua and
/// read off the same catalog builders the overview's bands call,
/// so a renamed verb moves its place with it.
extension ShortcutFold {
    @MainActor static func places(
        spaces: [SpaceID],
        desktops: [Int],
        resizeStep: Int
    ) -> [String: Place] {
        var out: [String: Place] = [:]
        func ladder(_ family: Family, _ pairs: [(Int?, NavCommand)]) {
            for case (let number?, let command) in pairs {
                out[command.lua] = Place(family: family, position: number)
            }
        }
        // A Space joins a ladder only when its id is a number's
        // own spelling.
        let numbers = spaces.map { space in
            Int(space.raw).flatMap { String($0) == space.raw ? $0 : nil }
        }
        let spaceLadders: [(Family, [NavCommand])] = [
            (.goToSpace, KeybindingCatalog.goToSpace(spaces)),
            (.moveToSpace, KeybindingCatalog.moveToSpaceRows(spaces)),
            (
                .moveToSpaceFollow,
                KeybindingCatalog.moveToSpaceFollowRows(spaces)
            ),
        ]
        for (family, commands) in spaceLadders {
            ladder(family, Array(zip(numbers, commands)))
        }
        let desktopLadders: [(Family, [NavCommand])] = [
            (.goToDesktop, KeybindingCatalog.goToDesktop(desktops)),
            (
                .moveToDesktop,
                KeybindingCatalog.moveToDesktopRows(desktops)
            ),
            (
                .moveToDesktopFollow,
                KeybindingCatalog.moveToDesktopFollowRows(desktops)
            ),
        ]
        for (family, commands) in desktopLadders {
            ladder(family, Array(zip(desktops.map { Optional($0) }, commands)))
        }
        for (family, members) in sets(resizeStep: resizeStep) {
            for (index, command) in members.enumerated() {
                out[command.lua] = Place(family: family, position: index)
            }
        }
        return out
    }

    /// Each set's members, in the order its folded label names
    /// them.
    @MainActor static func sets(
        resizeStep: Int
    ) -> [(Family, [NavCommand])] {
        func resize(
            _ rows: [KeybindingCatalog.ResizeRow]
        ) -> [NavCommand] {
            rows.map { KeybindingCatalog.resizeRow($0, step: resizeStep) }
        }
        return [
            (.focusDirections, KeybindingCatalog.focusDirections),
            (.swapDirections, KeybindingCatalog.swapDirections),
            (.spaceStep, KeybindingCatalog.spaceStepRows),
            (.spaceHistory, KeybindingCatalog.spaceHistoryRows),
            (.layoutCycle, KeybindingCatalog.layoutCycleRows),
            (.width, resize([.shrinkWidth, .growWidth])),
            (.height, resize([.shrinkHeight, .growHeight])),
        ]
    }
}
