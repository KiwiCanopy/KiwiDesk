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

    /// Halves area `id` (ruling 23) through Core's one door, which
    /// gives the new half the parent's bar values: the leading half
    /// keeps the id, so the selection and every pin stay on it.
    func splitArea(
        _ id: Int,
        on display: Display,
        _ axis: ScreenAreaCut.Axis
    ) {
        config.splitArea(
            id,
            axis,
            floor: areaFloor(axis),
            of: editableSplit(of: display),
            on: display.fingerprint,
            order: screenOrder
        )
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
        let fingerprint = display.fingerprint
        let survivor = config.mergeAreas(
            id,
            other,
            on: fingerprint,
            order: screenOrder
        )?
        .survivor.areaID
        // Merged back to whole where the saved setup had no split:
        // nothing to keep, so the Save books no row for a no-op.
        if let number = screenOrder.number(of: fingerprint),
            config.settings.displayAreas[number: number]?.isWhole == true,
            cleanConfig.settings.displayAreas[number: number] == nil
        {
            config.settings.displayAreas[number: number] = nil
        }
        return survivor
    }

    /// Every member of the run area `id` sits in as long as an
    /// even split makes it, none below the floor (#3541).
    func evenOutAreas(holding id: Int, on display: Display) {
        guard let split = areaSplit(of: display) else { return }
        writeAreaSplit(evenedOut(split, holding: id), on: display)
    }

    /// Whether Even Out would change the run area `id` sits in, as
    /// stored: shares step by 1‰, so a run already even to that step
    /// offers nothing (#3647 ▸ lane 3).
    func canEvenOut(holding id: Int, on display: Display) -> Bool {
        guard let split = areaSplit(of: display) else { return false }
        let width = Int(display.frame.width)
        let height = Int(display.frame.height)
        let stored = ScreenShares(split, width: width, height: height)
        return ScreenShares(
            evenedOut(split, holding: id),
            width: width,
            height: height,
            keeping: stored
        ) != stored
    }

    private func evenedOut(_ split: ScreenSplit, holding id: Int)
        -> ScreenSplit
    {
        let axis = split.run(holding: id)?.axis ?? .sideBySide
        return split.evenedOut(holding: id, floor: areaFloor(axis))
    }

    /// Writes `split` back for `display` — a divider's release or a
    /// typed size, each already clamped by Core.
    func writeAreaSplit(_ split: ScreenSplit, on display: Display) {
        config.settings.displayAreas.store(
            split,
            on: display.fingerprint,
            order: screenOrder
        )
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
            splits: draftSplits,
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
        writeAreaSplit(split, on: display)
    }

    /// The draft's splits in points, keyed by fingerprint: the
    /// connected screens in the draft's numbering, then each of its
    /// setups' screens in their own (#3647 ▸ lane 3).
    var draftSplits: [String: ScreenSplit] {
        config.settings.displayAreas.splits(
            order: screenOrder,
            sets: draftMonitorSets
        )
    }
}
