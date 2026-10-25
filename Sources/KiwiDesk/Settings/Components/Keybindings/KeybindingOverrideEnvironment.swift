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

/// Set on a card whose rows end in a trash: a trash-less row in
/// it reads this key and holds `AppRuleDeleteButton.slot`, so its
/// reach and key columns line up with the trash rows'.
private struct KeybindingReservesTrashSlotKey: EnvironmentKey {
    static let defaultValue = false
}

/// Whether no Hyper key is set (#1870), read once per section render:
/// a recorder holding a Hyper chord then dims in place, and one
/// recording reads F18 as held Hyper only while this is false
/// (#2414). False by default, so a mount outside `ShortcutsSection`
/// never dims but does read F18 as Hyper.
private struct HyperKeyIsOffKey: EnvironmentKey {
    static let defaultValue = false
}

/// What a recording keeps of a modifier's side (#2601), read once
/// per section render beside `hyperKeyIsOff`: nil while the switch
/// is off, so a mount outside the wiring sites records either-side.
private struct RecorderSidesKey: EnvironmentKey {
    static let defaultValue: RecorderSides? = nil
}

extension EnvironmentValues {
    var recorderSides: RecorderSides? {
        get { self[RecorderSidesKey.self] }
        set { self[RecorderSidesKey.self] = newValue }
    }

    var hyperKeyIsOff: Bool {
        get { self[HyperKeyIsOffKey.self] }
        set { self[HyperKeyIsOffKey.self] = newValue }
    }

    var disabledSystemShortcuts: Set<SystemShortcut> {
        get { self[DisabledSystemShortcutsKey.self] }
        set { self[DisabledSystemShortcutsKey.self] = newValue }
    }

    /// Whether a trash-less row holds the trash's width.
    var keybindingReservesTrashSlot: Bool {
        get { self[KeybindingReservesTrashSlotKey.self] }
        set { self[KeybindingReservesTrashSlotKey.self] = newValue }
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

extension View {
    /// What every recorder mount hands its fields about the keys:
    /// whether a Hyper key is set (#1870) and which sides a recording
    /// keeps (#2601). Each file hosting a `RecorderCoordinator`
    /// calls it (`ModifierSideRecorderTests` ▸ `mountsWireTheSides`).
    @MainActor
    func recorderKeys(_ model: SettingsModel) -> some View {
        // Hyper rows dim in place while no key is set (#1870).
        environment(\.hyperKeyIsOff, model.appWide.hyperKey == nil)
            .environment(\.recorderSides, model.recorderSides)
    }
}
