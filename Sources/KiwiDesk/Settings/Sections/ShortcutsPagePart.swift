import KiwiDeskCore

/// One child of the Shortcuts page's lazy stack, in page order
/// (#3060). The stack builds a part only once it nears the
/// viewport, so a scroll to a row inside an unbuilt part goes to the
/// part first: its `id` is known to the stack before the part is
/// built, a row's id is not.
enum ShortcutsPagePart: String, CaseIterable, Identifiable {
    case conflictBanner
    case modifierKeys
    case gestures
    case header
    case layers
    case showHide
    case focus
    case moveWindows
    case macosDesktops
    case layout
    case sizeFloat
    case pocket
    case openApplications
    case inactive
    case luaBindings

    var id: String { "shortcuts.part." + rawValue }

    /// The part a jump chip's group is drawn in.
    init(_ group: ShortcutsJumpGroup) {
        switch group {
        case .gestures: self = .gestures
        case .showHide: self = .showHide
        case .focus: self = .focus
        case .moveWindows: self = .moveWindows
        case .macosDesktops: self = .macosDesktops
        case .layout: self = .layout
        case .sizeFloat: self = .sizeFloat
        case .pocket: self = .pocket
        case .openApplications: self = .openApplications
        case .luaBindings: self = .luaBindings
        }
    }

    /// The jump chip leading to this part, nil for a part with none.
    var group: ShortcutsJumpGroup? {
        ShortcutsJumpGroup.allCases.first { Self($0) == self }
    }

    /// The part that draws a census container's rows; nil for a
    /// container the page does not draw.
    init?(_ container: SettingsContainer) {
        switch container {
        case .modifierKeys: self = .modifierKeys
        case .gestures: self = .gestures
        case .defaultShortcuts: self = .header
        case .layers: self = .layers
        case .showHide: self = .showHide
        case .focus: self = .focus
        case .moveWindows: self = .moveWindows
        case .macosDesktops: self = .macosDesktops
        case .layout: self = .layout
        case .sizeAndFloat: self = .sizeFloat
        case .pocket: self = .pocket
        case .openApplications: self = .openApplications
        case .luaBindings: self = .luaBindings
        default: return nil
        }
    }

    /// The part drawing `anchor` — a catalog control's id, a census
    /// row's label key or a shortcut row's command — nil when none
    /// is known, which builds the whole page instead
    /// (`ShortcutsPagePartTests`).
    @MainActor static func owner(
        of anchor: String,
        expander: ShortcutsFamilyRows
    ) -> ShortcutsPagePart? {
        if let part = catalogOwners[anchor] { return part }
        for key in SettingKey.allCases {
            guard let area = key.placement.area,
                SettingsDestination(area: area) == .shortcuts,
                let part = key.placement.container.flatMap(Self.init)
            else { continue }
            if case .key(let label) = key.text.label, label == anchor {
                return part
            }
            if expander.rows(for: key)?.contains(where: {
                $0.lua == anchor
            }) == true {
                return part
            }
        }
        return nil
    }

    /// Catalog controls no census row labels: the cards' own titles
    /// and the sub-headings and drawers inside them.
    @MainActor private static var catalogOwners: [String: Self] {
        let catalog = SettingsCatalog.shortcuts
        var owners: [String: Self] = [:]
        for group in ShortcutsJumpGroup.allCases {
            owners[group.control.id] = Self(group)
        }
        let more: [(SettingsControl, Self)] = [
            (catalog.modifierKeys.control, .modifierKeys),
            (catalog.layersCard.control, .layers),
            (catalog.moveWindowsTracks.control, .moveWindows),
            (catalog.desktopMoves.control, .macosDesktops),
            (catalog.pocketAppAdd, .pocket),
            (catalog.kiwiHubKeys, .showHide),
            (catalog.kiwishelfKeys, .showHide),
            (catalog.kiwiVisionKeys, .showHide),
            (catalog.inactiveShortcuts, .inactive),
        ]
        for (control, part) in more { owners[control.id] = part }
        return owners
    }
}

extension SettingsModel {
    /// The id a reveal of `anchor` scrolls to first: the Shortcuts
    /// part drawing it, which the lazy stack may not have built yet
    /// (#3060). Nil elsewhere, and for an anchor no part is known to
    /// hold, which builds the whole page instead.
    func revealPart(for anchor: String) -> String? {
        guard destination == .shortcuts else { return nil }
        return ShortcutsPagePart.owner(
            of: anchor,
            expander: .ofDraft(self, layer: nav.shortcutsLayerSelection)
        )?.id
    }
}
