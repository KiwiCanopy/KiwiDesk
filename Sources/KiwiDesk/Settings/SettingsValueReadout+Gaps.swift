import CoreGraphics
import KiwiDeskCore

/// Gaps-area rows. The per-edge keys narrate their own point
/// value; the two master rows narrate the unified value the
/// slider shows, reading "mixed" the way `GapsEditor` does when
/// the edges disagree; the Lua-only per-space override expands
/// to a row per touched space.
extension SettingsValueReadout {
    static func gapsRows(
        _ key: GapsKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        let census = SettingKey.gaps(key)
        let oldGaps = old.settings.gapsGlobal
        let newGaps = new.settings.gapsGlobal
        switch key {
        case .outerTop:
            return [
                edgeRow(
                    census,
                    oldGaps.outer.top,
                    newGaps.outer.top
                )
            ]
        case .outerBottom:
            return [
                edgeRow(
                    census,
                    oldGaps.outer.bottom,
                    newGaps.outer.bottom
                )
            ]
        case .outerLeft:
            return [
                edgeRow(
                    census,
                    oldGaps.outer.left,
                    newGaps.outer.left
                )
            ]
        case .outerRight:
            return [
                edgeRow(
                    census,
                    oldGaps.outer.right,
                    newGaps.outer.right
                )
            ]
        case .innerHorizontal:
            return [
                edgeRow(
                    census,
                    oldGaps.inner.horizontal,
                    newGaps.inner.horizontal
                )
            ]
        case .innerVertical:
            return [
                edgeRow(
                    census,
                    oldGaps.inner.vertical,
                    newGaps.inner.vertical
                )
            ]
        case .outer:
            return [
                SettingsDiffRow.change(
                    census,
                    label: label(for: census),
                    old: unified([
                        oldGaps.outer.top, oldGaps.outer.bottom,
                        oldGaps.outer.left, oldGaps.outer.right,
                    ]),
                    new: unified([
                        newGaps.outer.top, newGaps.outer.bottom,
                        newGaps.outer.left, newGaps.outer.right,
                    ])
                )
            ]
        case .inner:
            return [
                SettingsDiffRow.change(
                    census,
                    label: label(for: census),
                    old: unified([
                        oldGaps.inner.horizontal,
                        oldGaps.inner.vertical,
                    ]),
                    new: unified([
                        newGaps.inner.horizontal,
                        newGaps.inner.vertical,
                    ])
                )
            ]
        case .perSpaceOverride:
            return overrideRows(
                census,
                old: old.settings.gapsOverride,
                new: new.settings.gapsOverride
            )
        }
    }

    private static func edgeRow(
        _ census: SettingKey,
        _ old: CGFloat,
        _ new: CGFloat
    ) -> SettingsDiffRow {
        .change(
            census,
            label: label(for: census),
            old: points(old),
            new: points(new)
        )
    }

    /// The master rows' display value: one number while the
    /// edges agree, "mixed" while they differ — matching what
    /// the unified slider itself reads.
    private static func unified(
        _ values: [CGFloat]
    ) -> String {
        guard let first = values.first,
            values.allSatisfy({ $0 == first })
        else {
            return L("diff.value.mixed", "mixed")
        }
        return points(first)
    }

    /// A structural row per space whose override was added,
    /// removed or edited — the instance is the space's own
    /// name, which IS its display label everywhere.
    private static func overrideRows(
        _ census: SettingKey,
        old: [SpaceID: Gaps],
        new: [SpaceID: Gaps]
    ) -> [SettingsDiffRow] {
        let base = L("diff.label.gap_override", "Gap override")
        var rows: [SettingsDiffRow] = []
        let touched = Set(old.keys).union(new.keys)
            .filter { old[$0] != new[$0] }
            .sorted { $0.raw < $1.raw }
        for space in touched {
            let note: String
            if old[space] == nil {
                note = addedNote
            } else if new[space] == nil {
                note = removedNote
            } else {
                note = editedNote
            }
            rows.append(
                .note(
                    census,
                    instance: space.raw,
                    label: instanceLabel(base, space.raw),
                    note: note
                )
            )
        }
        return rows
    }
}
