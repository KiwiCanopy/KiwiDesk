import Combine
import KiwiDeskCore

/// General's app-wide rows (#1741): read live from the core and
/// written at once, never through the draft — the card they sit
/// on promises "applies immediately".
extension SettingsModel {
    var appWide: AppWideSettings { core.appWide }

    /// What the Hyper key's remap last did (#1870), read live.
    var hyperStatus: HyperKeyStatus { core.keys.hyperStatus }

    /// Whether the active layer has a ✦ row, as registered (#2480).
    var hyperHasShortcuts: Bool { core.keys.hyperHasShortcuts }

    /// Takes over the leftover remap Core offered (#2471).
    func takeOverHyperRemap() {
        objectWillChange.send()
        core.takeOverHyperRemap()
    }

    func setAppWide(_ change: (inout AppWideSettings) -> Void) {
        objectWillChange.send()
        core.withUserMotion { core.setAppWide(persisting: true, change) }
    }
}

/// The sides switch's live reads (#2601).
extension SettingsModel {
    /// What a recording keeps of a side, nil while the switch is
    /// off.
    var recorderSides: RecorderSides? {
        appWide.modifierSides
            ? RecorderSides(hyperKey: appWide.hyperKey) : nil
    }

    /// What the side tap last did, read live.
    var sideTapStatus: SideTapStatus { core.keys.sideTapStatus }

    /// The draft's rows that keep a modifier's side, every layer.
    var sidedShortcutCount: Int {
        config.layers.flatMap(\.bindings).count {
            KeyCombo.parse($0.combo)?.modifiers.isSided == true
        }
    }
}
