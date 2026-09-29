import KiwiDeskCore

/// Navigation target specification in Settings window (#277,
/// #326). `anchor` is a `SettingsControl.id`, never display text
/// — the load-bearing decision: label-text anchors were
/// measured dead one level down (Appearance renders "Color" six
/// times; text `.id()` churn tears down rows holding uncommitted
/// `@State` mid-edit). The catalog declaration supplies both
/// label and id, so the render path stays the one list.
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
        case .space:
            return destination == .spaces ? surface : .main
        }
    }
}

/// Local surface selection within a settings destination
/// (#277, `SettingsDisclosure`).
enum SettingsSurface: Hashable {
    case main
    case layoutMode(LayoutMode)
    /// One Space's card on Spaces (#1518).
    case space(SpaceID)
}

extension SettingsAnchor {
    /// Where a bar menu's Settings row lands (#1518): the page,
    /// and the card or row on it, as the search would land.
    init(landing: SettingsLanding) {
        switch landing {
        case .shelf:
            self.init(
                destination: .bars,
                anchor: SettingsCatalog.bars.kiwishelfCard.id
            )
        case .looks:
            self.init(destination: .looks)
        case .advancedColors:
            self.init(destination: .advancedColors)
        case .space(let space):
            self.init(destination: .spaces, surface: .space(space))
        }
    }
}
