import KiwiDeskCore

/// Navigation target specification in Settings window (#277, #326).
struct SettingsAnchor: Hashable {
    let destination: SettingsDestination
    /// Local view surface required before revealing target.
    var surface: SettingsSurface = .main
    /// `SettingsControl.id` to reveal and flash, or nil for destination root
    /// (#326).
    var anchor: String?

    /// Resolves navigation decision against reachability and surface support
    /// (#18, #277, `SettingsView.apply`).
    func resolved(
        editingStoredProfile: Bool
    ) -> (
        destination: SettingsDestination,
        surface: SettingsSurface,
        scroll: String?
    )? {
        guard
            destination.isReachable(
                editingStoredProfile: editingStoredProfile
            )
        else { return nil }
        return (destination, renderableSurface, anchor)
    }

    /// Validates surface against destination capabilities, falling back to
    /// `.main`.
    private var renderableSurface: SettingsSurface {
        switch surface {
        case .main:
            return .main
        case .layoutMode(let mode):
            let renders =
                destination == .layoutDefaults
                && LayoutMode.placementTabs.contains(mode)
            return renders ? surface : .main
        }
    }
}

/// Local surface selection within a settings destination
/// (#277, `SettingsDisclosure`).
enum SettingsSurface: Hashable {
    case main
    case layoutMode(LayoutMode)
}
