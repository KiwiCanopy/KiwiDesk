import KiwiDeskCore

/// The Maximize card's diff rows (#3062): one per column. The
/// changed shape goes in the label, so the readout carries only the
/// values and fits the pill's value column: "…, Laptop" with
/// "75% → 40%", or "…, Laptop +2" with the first shape's values.
extension SettingsValueReadout {
    static func maximizeRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        let old = before.maximize
        let new = after.maximize
        let change: ShapeChange?
        switch key {
        case .maximizeHeightShare:
            change = changed(old.heightShare, new.heightShare, percent)
        case .maximizeWidthShare:
            change = changed(old.widthShare, new.widthShare, percent)
        default:
            change = changed(old.anchor, new.anchor, MaximizeCard.anchorName)
        }
        guard let change else { return [] }
        return [
            .change(
                census,
                label: L(
                    "layout_defaults.maximize.diff_label",
                    "%1$@, %2$@",
                    label(for: census),
                    change.shapes
                ),
                old: change.old,
                new: change.new
            )
        ]
    }

    /// A Space's own Maximize rows (#3090): one per Space whose
    /// value moved, unset where it follows its screen's shape.
    static func maximizeSpaceRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        let read: (MaximizeSettings, SpaceID) -> String? = { settings, space in
            switch key {
            case .maximizeHeightSharePerSpace:
                settings.shareOverride[space]?.height.map(percent)
            case .maximizeWidthSharePerSpace:
                settings.shareOverride[space]?.width.map(percent)
            default:
                settings.anchorOverride[space].map(MaximizeCard.anchorName)
            }
        }
        let old = before.maximize
        let new = after.maximize
        let spaces = Set(old.shareOverride.keys)
            .union(new.shareOverride.keys)
            .union(old.anchorOverride.keys)
            .union(new.anchorOverride.keys)
            .filter { read(old, $0) != read(new, $0) }
            .sorted { $0.raw < $1.raw }
        return spaces.map { space in
            .change(
                census,
                instance: space.raw,
                label: instanceLabel(label(for: census), space.raw),
                old: read(old, space) ?? unset,
                new: read(new, space) ?? unset
            )
        }
    }

    /// The changed shapes named for the label, and the first one's
    /// values before and after.
    struct ShapeChange {
        let shapes: String
        let old: String
        let new: String
    }

    @MainActor
    static func changed<Value>(
        _ old: PerScreenShape<Value>,
        _ new: PerScreenShape<Value>,
        _ format: (Value) -> String
    ) -> ShapeChange? {
        let shapes = ScreenShape.allCases.filter { old[$0] != new[$0] }
        // Nothing changed narrates the first shape's value, as every
        // readout narrates its value at rest.
        guard let first = shapes.first ?? ScreenShape.allCases.first
        else { return nil }
        let name = MaximizeShapeText.name(first)
        return ShapeChange(
            shapes: shapes.count <= 1
                ? name
                : L(
                    "layout_defaults.maximize.diff_more",
                    "%1$@ +%2$d",
                    name,
                    shapes.count - 1
                ),
            old: format(old[first]),
            new: format(new[first])
        )
    }
}
