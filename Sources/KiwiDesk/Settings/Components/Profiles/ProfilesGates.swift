import KiwiDeskCore

/// Resolves inert gate reasons for the Profiles settings area
/// (#678 Phase 3, turn 13a, 8c, #888).
struct ProfilesGates {
    /// Whether dashboard is editing a stored profile rather than live config
    /// (#18).
    let editingStoredProfile: Bool
    /// Current count of connected physical displays.
    let connectedScreens: Int
    /// `KiwiCore.isGuiManaged`: false where init.lua owns the
    /// config, so there is no sidecar to file a binding into.
    let guiManaged: Bool
    /// Preset row's OWN screen count; nil on every other row — a
    /// `presetsApply` resolve with nil is a caller that forgot to
    /// pass it, which asserts rather than silently (not) greying.
    var presetScreens: Int?

    /// Reason why a setting control is currently disabled/inert.
    enum InertReason: Hashable {
        case bindingsOwnedByLua
        case presetSwitchesLiveLayout
        case screenCountMismatch(screens: Int)
    }

    /// Evaluates inert reason for setting key. Fail-OPEN on a
    /// gate this type does not own — loud in debug, live in
    /// release: a live row the user can ignore beats a dead one
    /// they cannot explain. `everyGatedRowIsResolved` keeps that
    /// arm unreachable rather than merely believed to be.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .profiles(.profileBindings):
            return guiManaged ? nil : .bindingsOwnedByLua
        case .profiles(.presetsApply):
            if editingStoredProfile {
                return .presetSwitchesLiveLayout
            }
            guard let screens = presetScreens else {
                assertionFailure(
                    "presetsApply resolved without a preset "
                        + "screen count"
                )
                return nil
            }
            return screens == connectedScreens
                ? nil : .screenCountMismatch(screens: screens)
        default:
            assertionFailure(
                "unhandled Profiles gate: \(key.id)"
            )
            return nil
        }
    }

    /// Gated setting keys resolved by this type (`everyGatedRowIsResolved`).
    static let resolved: Set<SettingKey> = [
        .profiles(.profileBindings),
        .profiles(.presetsApply),
    ]

    /// Gated setting keys resolved outside this type.
    static let resolvedElsewhere: Set<SettingKey> = []
}

/// Localized explanatory text for disabled Profiles settings controls
/// (#678, #888).
@MainActor
enum ProfilesGateHelp {
    static func sentence(
        for reason: ProfilesGates.InertReason
    ) -> String {
        switch reason {
        case .bindingsOwnedByLua:
            // The reader is a Lua author by construction (the
            // gate), so the verb is named — interpolated, never
            // in the frame (gui.md).
            return L(
                "profiles.desktops.lua_owned",
                "Your init.lua owns the Desktop bindings — "
                    + "edit its %1$@ lines there.",
                "bind_profile_to_desktop"
            )
        case .presetSwitchesLiveLayout:
            return L(
                "presets.editing_stored",
                "Applying a preset switches your live layout, "
                    + "which editing a saved profile never does. "
                    + "Switch to Live to apply one."
            )
        case .screenCountMismatch(let screens):
            return L(
                "presets.needs_screens",
                "Needs %1$d connected screen(s).",
                screens
            )
        }
    }
}
