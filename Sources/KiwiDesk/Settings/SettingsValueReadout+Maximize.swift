import KiwiDeskCore

/// The Maximize card's diff rows (#3062): one per column, naming the
/// screen shapes whose value changed.
extension SettingsValueReadout {
    static func maximizeRows(
        _ key: BehaviourKey,
        _ census: SettingKey,
        _ before: TilingSettings,
        _ after: TilingSettings
    ) -> [SettingsDiffRow] {
        let old = before.maximize
        let new = after.maximize
        let pair: (old: String, new: String)
        switch key {
        case .maximizeHeightShare:
            pair = changed(old.heightShare, new.heightShare, percent)
        case .maximizeWidthShare:
            pair = changed(old.widthShare, new.widthShare, percent)
        default:
            pair = changed(old.anchor, new.anchor, MaximizeCard.anchorName)
        }
        return [
            .change(
                census,
                label: label(for: census),
                old: pair.old,
                new: pair.new
            )
        ]
    }

    /// Each changed shape's value before and after, "Laptop 75%".
    @MainActor
    private static func changed<Value>(
        _ old: PerScreenShape<Value>,
        _ new: PerScreenShape<Value>,
        _ format: (Value) -> String
    ) -> (old: String, new: String) {
        let shapes = ScreenShape.allCases.filter { old[$0] != new[$0] }
        func list(_ values: PerScreenShape<Value>) -> String {
            shapes.map {
                L(
                    "layout_defaults.maximize.diff_value",
                    "%1$@ %2$@",
                    MaximizeShapeText.name($0),
                    format(values[$0])
                )
            }
            .joined(separator: ", ")
        }
        return (list(old), list(new))
    }
}
