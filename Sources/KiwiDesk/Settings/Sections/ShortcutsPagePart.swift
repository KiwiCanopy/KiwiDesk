import Foundation
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

    /// The part a jump chip's group is drawn in: its container's
    /// (`ShortcutsPagePartTests` ▸ `chipsMatchParts`).
    init(_ group: ShortcutsJumpGroup) {
        self = Self(group.container)!
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
    /// row's label key, a shortcut row's command or a binding row's
    /// id among `bindings` — nil when none is known, which builds the
    /// whole page instead (`ShortcutsPagePartTests`).
    @MainActor static func owner(
        of anchor: String,
        expander: ShortcutsFamilyRows,
        bindings: [KeyBinding]
    ) -> ShortcutsPagePart? {
        if let part = catalogOwners[anchor] { return part }
        if let binding = bindings.first(where: {
            $0.kind != .navigation && $0.id.uuidString == anchor
        }) {
            return owner(of: binding)
        }
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

    /// The part drawing a binding row the recorder names by id.
    private static func owner(of binding: KeyBinding) -> ShortcutsPagePart {
        if PocketAppLuaArg.bundleID(of: binding.lua) != nil { return .pocket }
        return binding.kind == .application ? .openApplications : .luaBindings
    }

    /// Catalog controls no census row labels — the cards' own titles,
    /// the sub-headings and drawers inside them — and the Mouse &
    /// trackpad entries a strip click lands on. A control added to the
    /// page or moved between cards is placed here.
    @MainActor private static let catalogOwners: [String: Self] = {
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
        for item in GestureItem.allCases { owners[item.anchor] = .gestures }
        return owners
    }()
}

/// Where a reveal of an anchor goes before the anchor itself on a
/// lazily built page (#3060).
enum RevealLanding: Equatable {
    /// Scroll to this part's id first, so the stack builds it.
    case part(String)
    /// No part is known to hold the anchor: build the whole page.
    case wholePage
}

extension SettingsModel {
    /// How a reveal of `anchor` reaches it on a lazily built page;
    /// nil where the anchor is already in the stack — every page but
    /// Shortcuts, and a Shortcuts part the page holds built (#3060).
    func revealLanding(for anchor: String) -> RevealLanding? {
        switch destination {
        case .shortcuts:
            let layer = nav.shortcutsLayerSelection
            let owner = ShortcutsPagePart.owner(
                of: anchor,
                expander: .ofDraft(self, layer: layer),
                bindings: config.layers.first { $0.name == layer }?.bindings
                    ?? []
            )
            guard let owner else { return .wholePage }
            return shortcutsPartsBuilt.contains(owner)
                ? nil : .part(owner.id)
        default:
            return nil
        }
    }
}
