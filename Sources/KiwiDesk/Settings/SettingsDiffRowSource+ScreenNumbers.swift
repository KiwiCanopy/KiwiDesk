import KiwiDeskCore

/// The row the pill owes a renumber (#3647 ▸ lane 2): ONE row for
/// the whole order, since a swap moves two screens and a ↺ on half
/// of it would leave two Screen 1s.
extension SettingsDiffRowSource {
    static func screenNumberRows(
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        guard let draft = model.screenNumbering.draft else { return [] }
        var row = SettingsDiffRow.change(
            .screens(.screenNumbers),
            label: L("diff.label.screen_numbers", "Screen numbers"),
            old: numbering(model.baseScreenOrder, model),
            new: numbering(draft, model)
        )
        row.jumpsToAreaRoot = true
        row.revert = .screenNumbers
        return [row]
    }

    /// The screens in number order, an unnumbered one last.
    private static func numbering(
        _ order: ScreenOrder,
        _ model: SettingsModel
    ) -> String {
        let screens = model.displays
        var named: [String] = []
        var left: [String] = []
        for (index, fingerprint) in order.fingerprints.enumerated() {
            guard
                let display = screens.first(where: {
                    $0.fingerprint == fingerprint
                })
            else { continue }
            let name = model.screenLabel(display)
            if order.unnumbered.contains(index + 1) {
                left.append(
                    L(
                        "diff.value.screen_unnumbered",
                        "%1$@ not numbered",
                        name
                    )
                )
            } else {
                named.append(
                    L("diff.value.screen_number", "%1$d %2$@", index + 1, name)
                )
            }
        }
        return (named + left).joined(separator: " · ")
    }
}
