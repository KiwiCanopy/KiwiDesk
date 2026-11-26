import Foundation
import KiwiDeskCore

/// Screens settings diff readout generators.
extension SettingsValueReadout {
    static func screensRows(
        _ key: ScreensKey,
        old: GuiConfig,
        new: GuiConfig,
        order: ScreenOrder?
    ) -> [SettingsDiffRow] {
        let census = SettingKey.screens(key)
        switch key {
        case .spacePins:
            let words = { (slot: ScreenSlotKey) in
                screenWords(slot, order, new.settings.displayAreas)
            }
            return screensPinRows(
                census,
                old: old.spacePins.mapValues(words),
                new: new.spacePins.mapValues(words)
            )
        case .mainSpaces:
            return screensMainRows(
                census,
                old: old.mainSpaces,
                new: new.mainSpaces
            )
        case .displayAreas:
            return screensAreaRows(
                census,
                old: old.settings.displayAreas,
                new: new.settings.displayAreas
            )
        case .orphanPinClear, .fingerprints,
            .placementUnavailable, .screenNumbers:
            // no model path — never booked by the diff
            return []
        }
    }

    /// One row per re-pinned space, naming the stored screen number
    /// as "Screen N" (#3647), an area pin as "Screen N – Area k".
    private static func screensPinRows(
        _ census: SettingKey,
        old: [SpaceID: String],
        new: [SpaceID: String]
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.space_pin", "Screen pin")
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .change(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                old: old[space] ?? unset,
                new: new[space] ?? unset
            )
        }
    }

    /// A stored pin's words: "Screen N", and an area pin "Screen N –
    /// Left", its area worded on the screen holding N in `order`.
    private static func screenWords(
        _ slot: ScreenSlotKey,
        _ order: ScreenOrder?,
        _ splits: [String: ScreenSplit]
    ) -> String {
        let screen = L("monitor_card.number_badge", "Screen %1$d", slot.number)
        guard slot.areaID > 0 else { return screen }
        guard let key = order?.runtimeKey(of: slot) else {
            return L(
                "monitors.split.name",
                "%1$@ – %2$@",
                screen,
                ScreenAreaWords.position(.numbered(slot.areaID + 1))
            )
        }
        return SettingsModel.perScreenName(
            screen: screen,
            key: key.description,
            splits: splits
        )
    }

    /// One row per screen whose split changed (#3517), each side
    /// read as its areas in reading order — id, name and size — so
    /// a re-split that changes only ids, or a rename, never reads
    /// alike on both sides.
    private static func screensAreaRows(
        _ census: SettingKey,
        old: [String: ScreenSplit],
        new: [String: ScreenSplit]
    ) -> [SettingsDiffRow] {
        let base = L("monitors.areas.label", "Screen areas")
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted()
        return touched.map { screen in
            .change(
                census,
                instance: screen,
                label: instanceLabel(base, screen),
                old: old[screen].map(areaSizes) ?? unset,
                new: new[screen].map(areaSizes) ?? unset
            )
        }
    }

    private static func areaSizes(_ split: ScreenSplit) -> String {
        ScreenArea.readingOrder(split.areas)
            .map { area in
                if let name = area.name {
                    return L(
                        "diff.value.screen_area.named",
                        "#%1$d “%2$@” %3$d×%4$d",
                        area.id,
                        name,
                        area.w,
                        area.h
                    )
                }
                return L(
                    "diff.value.screen_area",
                    "#%1$d %2$d×%3$d",
                    area.id,
                    area.w,
                    area.h
                )
            }
            .joined(separator: " · ")
    }

    /// Diff rows for spaces joining or leaving the follows-main set.
    private static func screensMainRows(
        _ census: SettingKey,
        old: Set<SpaceID>,
        new: Set<SpaceID>
    ) -> [SettingsDiffRow] {
        let base = label(for: census)
        let touched = old.symmetricDifference(new)
            .sorted { $0.raw < $1.raw }
        return touched.map { space in
            .note(
                census,
                instance: space.raw,
                label: instanceLabel(base, space.raw),
                note: new.contains(space)
                    ? addedNote : removedNote
            )
        }
    }
}
