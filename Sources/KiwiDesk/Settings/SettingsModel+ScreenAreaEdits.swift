import CoreGraphics
import Foundation
import KiwiDeskCore

/// The Screens editor's writes of a screen's split (#3517 rulings
/// 22–26), all into the draft's `display_areas`. Every floor and
/// every legality answer is Core's: `TilingSettings.areaFloor`,
/// `ScreenSplit.splitting`, `merging`, `moving` and `setting`.
extension SettingsModel {
    /// The fewest points the editor leaves an area along `axis`.
    func areaFloor(_ axis: ScreenAreaCut.Axis) -> Int {
        config.settings.areaFloor(along: axis)
    }

    /// Whether area `id` of `display` halves along `axis` with both
    /// halves above the floor.
    func canSplit(
        _ id: Int,
        on display: Display,
        _ axis: ScreenAreaCut.Axis
    ) -> Bool {
        editableSplit(of: display)
            .splitting(id, axis, floor: areaFloor(axis)) != nil
    }

    /// Halves area `id` (ruling 23): the leading half keeps the id,
    /// so the selection and every pin stay on it.
    func splitArea(
        _ id: Int,
        on display: Display,
        _ axis: ScreenAreaCut.Axis
    ) {
        guard
            let next = editableSplit(of: display)
                .splitting(id, axis, floor: areaFloor(axis))
        else { return }
        config.settings.displayAreas[display.fingerprint] = next
    }

    /// The areas `id` shares a full edge with, in reading order.
    func mergeNeighbours(of id: Int, on display: Display) -> [Int] {
        guard let split = areaSplit(of: display) else { return [] }
        return ScreenArea.readingOrder(split.areas).map(\.id).filter {
            $0 != id && split.merging(id, $0) != nil
        }
    }

    /// Merges `id` with `other` through Core's one door, which
    /// rewrites the draft's pins and per-screen maps (ruling 22).
    /// Returns the area that survived.
    @discardableResult
    func mergeArea(
        _ id: Int,
        with other: Int,
        on display: Display
    ) -> Int? {
        config.mergeAreas(id, other, on: display.fingerprint)?
            .survivor.areaID
    }

    /// Every area of `display` as long as an even split makes it.
    func evenOutAreas(on display: Display) {
        guard let split = areaSplit(of: display) else { return }
        config.settings.displayAreas[display.fingerprint] =
            split.evenedOut(
                width: Int(display.frame.width),
                height: Int(display.frame.height)
            )
    }

    /// Writes `split` back for `display` — a divider's release or a
    /// typed size, each already clamped by Core.
    func writeAreaSplit(_ split: ScreenSplit, on display: Display) {
        config.settings.displayAreas[display.fingerprint] = split
    }

    /// Why `name` cannot name area `id`, through Core's one rule.
    func areaNameProblem(
        _ name: String,
        for id: Int,
        on display: Display
    ) -> ScreenAreaNameProblem? {
        ScreenArea.nameProblem(
            name.trimmingCharacters(in: .whitespaces),
            for: ScreenAreaKey(
                fingerprint: display.fingerprint,
                areaID: id
            ),
            splits: config.settings.displayAreas,
            screenNames: displays.map(\.name)
        )
    }

    /// Names area `id`; an empty name clears it back to the
    /// positional default.
    func renameArea(_ id: Int, on display: Display, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard areaNameProblem(trimmed, for: id, on: display) == nil,
            var split = areaSplit(of: display),
            let at = split.areas.firstIndex(where: { $0.id == id })
        else { return }
        split.areas[at].name = trimmed.isEmpty ? nil : trimmed
        config.settings.displayAreas[display.fingerprint] = split
    }
}
