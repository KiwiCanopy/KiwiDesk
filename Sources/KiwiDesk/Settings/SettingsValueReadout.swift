import CoreGraphics
import KiwiDeskCore

/// Formats changed settings keys into diff rows for draft review
/// (`SettingsDraftDiff`, `SettingsValueReadoutTests`, #678 turn 9).
@MainActor
enum SettingsValueReadout {
    /// Returns diff rows describing changes between clean and draft configs.
    static func rows(
        for key: SettingKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        switch key {
        case .appBar(let k):
            return appBarRows(k, old: old, new: new)
        case .appRules(let k):
            return appRulesRows(k, old: old, new: new)
        case .behaviour(let k):
            return behaviourRows(k, old: old, new: new)
        case .borders(let k):
            return bordersRows(k, old: old, new: new)
        case .colours(let k):
            return coloursRows(k, old: old, new: new)
        case .gaps(let k):
            return gapsRows(k, old: old, new: new)
        case .general(let k):
            return generalRows(k, old: old, new: new)
        case .layout(let k):
            return layoutRows(k, old: old, new: new)
        case .layoutAppBar(let k):
            return layoutAppBarRows(k, old: old, new: new)
        case .monitors(let k):
            return monitorsRows(k, old: old, new: new)
        case .profiles(let k):
            return profilesRows(k, old: old, new: new)
        case .shortcuts(let k):
            return shortcutsRows(k, old: old, new: new)
        case .spaceBar(let k):
            return spaceBarRows(k, old: old, new: new)
        case .spaces(let k):
            return spacesRows(k, old: old, new: new)
        }
    }

    /// Census keys exempt from diff narration (`SettingsValueReadoutTests`).
    static let noReadout: Set<SettingKey> = []
}

// MARK: - Shared value formatting

extension SettingsValueReadout {
    /// Formats point value string (e.g. "8 pt").
    static func points(_ value: CGFloat) -> String {
        L("diff.value.points", "%1$@ pt", trimmed(value))
    }

    /// Formats millisecond duration string (e.g. "150 ms").
    static func milliseconds(_ value: Double) -> String {
        L("diff.value.milliseconds", "%1$@ ms", trimmed(value))
    }

    /// Formats percentage string (e.g. "50%").
    static func percent(_ fraction: Double) -> String {
        L(
            "diff.value.percent",
            "%1$@%%",
            trimmed((fraction * 100).rounded())
        )
    }

    /// Formats hex color string with leading `#`.
    static func hexDisplay(_ hex: String) -> String {
        let digits =
            hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        return "#" + digits.uppercased()
    }

    /// Formats points with `0` as "Automatic" (#551).
    static func autoPoints(_ value: CGFloat) -> String {
        value == 0
            ? L("settings.readout.auto", "Automatic")
            : points(value)
    }

    /// Formats boolean toggle state.
    static func onOff(_ value: Bool) -> String {
        value
            ? L("diff.value.on", "On")
            : L("diff.value.off", "Off")
    }

    /// Strips trailing `.0` on numbers.
    static func trimmed(_ value: CGFloat) -> String {
        trimmed(Double(value))
    }

    static func trimmed(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    /// Formats label for an instanced row (e.g. "Monocle · thickness").
    static func instanceLabel(
        _ base: String,
        _ instance: String
    ) -> String {
        L(
            "diff.label.instance",
            "%1$@ · %2$@",
            base,
            instance
        )
    }

    /// Placeholder for unset value.
    static var unset: String {
        L("diff.value.unset", "—")
    }

    static var addedNote: String {
        L("diff.note.added", "Added")
    }
    static var removedNote: String {
        L("diff.note.removed", "Removed")
    }
    static var editedNote: String {
        L("diff.note.edited", "Edited")
    }

    /// Resolves human-readable label for key (`SettingsCensusLabel`).
    static func label(for key: SettingKey) -> String {
        SettingsCensusLabel.label(for: key) ?? key.id
    }
}
