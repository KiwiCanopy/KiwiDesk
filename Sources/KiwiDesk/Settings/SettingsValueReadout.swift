import CoreGraphics
import KiwiDeskCore

/// Turns a changed census key into display-ready diff rows
/// (#678 turn 9, digest §1.1): the per-key half the
/// count-only chip deliberately shipped without, built here so
/// the panel's "CHANGED IN THIS DRAFT" list and Home's popover
/// can state old → new instead of only that something changed.
///
/// `SettingsDraftDiff` stays the attribution authority — it
/// says WHICH settings changed; this type only narrates a key
/// it is handed. An instanced key (a per-space override, an
/// app rule) expands to one row per touched instance, labelled
/// through the census key's own label plus the instance —
/// which is why the return is a list.
///
/// Totality is guarded, not promised: every census key whose
/// id names a model path (`settings.*` / `config.*`) must
/// produce at least one row for a config pair that differs on
/// that path, or sit in `noReadout` with its reason —
/// `SettingsValueReadoutTests` reds the key that lands in
/// neither.
@MainActor
enum SettingsValueReadout {
    /// Rows for one changed key. `old` is the clean baseline,
    /// `new` the draft.
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

    /// Census keys with a model path but no diff narration, and
    /// why not — the readout totality guard's one exemption
    /// list. Internal-only storage never reaches the diff
    /// (`SettingsDraftDiff` counts it, the popover shows its
    /// area's rows); keys land here only with an argument.
    static let noReadout: Set<SettingKey> = []
}

// MARK: - Shared value formatting

extension SettingsValueReadout {
    /// "8 pt" — the unit frame every point-valued row shares.
    static func points(_ value: CGFloat) -> String {
        L("diff.value.points", "%1$@ pt", trimmed(value))
    }

    /// "150 ms".
    static func milliseconds(_ value: Double) -> String {
        L("diff.value.milliseconds", "%1$@ ms", trimmed(value))
    }

    /// "50 %".
    static func percent(_ fraction: Double) -> String {
        L(
            "diff.value.percent",
            "%1$@ %%",
            trimmed((fraction * 100).rounded())
        )
    }

    /// Localized On / Off — toggles narrate their state, never
    /// true/false.
    static func onOff(_ value: Bool) -> String {
        value
            ? L("diff.value.on", "On")
            : L("diff.value.off", "Off")
    }

    /// A bare number, `.0` trimmed.
    static func trimmed(_ value: CGFloat) -> String {
        trimmed(Double(value))
    }

    static func trimmed(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }

    /// "Monocle · thickness" — the instanced-row label frame.
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

    /// The unset side of a pair that gained or lost its value —
    /// the prototype's "— → 44 pt".
    static var unset: String {
        L("diff.value.unset", "—")
    }

    /// Structural one-worders for rows without a scalar pair.
    static var addedNote: String {
        L("diff.note.added", "Added")
    }
    static var removedNote: String {
        L("diff.note.removed", "Removed")
    }
    static var editedNote: String {
        L("diff.note.edited", "Edited")
    }

    /// The census label for a key, or its id as the visible
    /// last resort (`SettingsCensusLabel` argues the chain).
    static func label(for key: SettingKey) -> String {
        SettingsCensusLabel.label(for: key) ?? key.id
    }
}
