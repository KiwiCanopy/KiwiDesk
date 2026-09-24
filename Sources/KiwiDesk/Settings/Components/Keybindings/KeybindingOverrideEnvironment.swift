import KiwiDeskCore
import SwiftUI

/// Environment keys for Shortcuts tab profile override rendering (#55, #17).
private struct KeybindingLayerNameKey: EnvironmentKey {
    static let defaultValue = KeyLayer.defaultName
}

/// The switched-off system shortcuts (#1105), read ONCE per
/// section render and handed down — never one read per row.
///
/// The empty default is NOT the shipped reading: six chords ship
/// disabled, so a row rendered outside `ShortcutsSection` would
/// over-report `.dead`. What keeps that unreachable is that
/// every recorder mount descends from the one wiring site, which
/// `ConflictRowTreatmentTests` pins (#1126).
private struct DisabledSystemShortcutsKey: EnvironmentKey {
    static let defaultValue: Set<SystemShortcut> = []
}

extension EnvironmentValues {
    var disabledSystemShortcuts: Set<SystemShortcut> {
        get { self[DisabledSystemShortcutsKey.self] }
        set { self[DisabledSystemShortcutsKey.self] = newValue }
    }

    /// Name of layer whose keybindings are currently rendered.
    var keybindingLayerName: String {
        get { self[KeybindingLayerNameKey.self] }
        set { self[KeybindingLayerNameKey.self] = newValue }
    }
}

extension View {
    /// Dims an unavailable row and speaks why (#678 turn 20a rule
    /// 3). It stays EDITABLE — dim, never disable. Which profiles a
    /// row reaches is its "Applies to" column's to say (#1393), so
    /// there is no inherited dim.
    func keybindingRowStyle(unavailable: String?) -> some View {
        opacity(unavailable != nil ? 0.55 : 1)
            .accessibilityHint(unavailable ?? "")
    }
}
