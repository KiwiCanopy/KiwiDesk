import Foundation
import KiwiDeskCore

/// One child of the Shortcuts page's lazy stack, in page order
/// (#3060), each drawn in the segments `segments` names (#3184).
/// The stack builds a part only once it nears the viewport, so a
/// scroll to a row inside an unbuilt part goes to the part first:
/// its `id` is known to the stack before the part is built, a row's
/// id is not.
enum ShortcutsPagePart: String, CaseIterable, Identifiable {
    case conflictBanner
    case modifierKeys
    case layers
    // Under the layer pick that gates it, above the groups it
    // rewrites (#3074, #3179).
    case defaultShortcuts
    case showHide
    case focus
    case moveWindows
    case macosDesktops
    case layout
    case sizeFloat
    case pocket
    case inactive
    case openApplications
    case keySequences
    case luaBindings
    case gestures

    var id: String { "shortcuts.part." + rawValue }

    /// The segments drawing this part. Layers draws on both key
    /// parts, reading the one `nav.shortcutsLayer`; the conflict
    /// banner on both too (#3184).
    var segments: [ShortcutsSegment] {
        switch self {
        case .conflictBanner, .layers: return [.builtIn, .personal]
        case .openApplications, .keySequences, .luaBindings:
            return [.personal]
        case .gestures: return [.mouse]
        default: return [.builtIn]
        }
    }

    /// The segment a reveal of this part lands on: the one shown
    /// when it draws there, its first otherwise.
    func segment(from shown: ShortcutsSegment) -> ShortcutsSegment {
        segments.contains(shown) ? shown : segments[0]
    }

    /// `segment`'s parts, in page order.
    static func parts(in segment: ShortcutsSegment) -> [Self] {
        allCases.filter { $0.segments.contains(segment) }
    }

    /// The part a jump chip's group is drawn in: its container's
    /// (`ShortcutsPagePartTests` ▸ `chipsMatchParts`).
    init(_ group: ShortcutsJumpGroup) {
        self = Self(group.container)!
    }

    /// The jump chip leading to this part, nil for a part with none.
    var group: ShortcutsJumpGroup? {
        ShortcutsJumpGroup.allCases.first { Self($0) == self }
    }

    /// Whether the page draws a rule above this part in `segment`:
    /// between Built-in's Modifier keys, which apply on every layer,
    /// and the layer's own rows (owner 2026-11-08).
    func ruledAbove(in segment: ShortcutsSegment) -> Bool {
        let parts = Self.parts(in: segment)
        guard let at = parts.firstIndex(of: self), at > 0 else {
            return false
        }
        return self == .layers && parts[at - 1] == .modifierKeys
    }

    /// The part that draws a census container's rows; nil for a
    /// container the page does not draw.
    init?(_ container: SettingsContainer) {
        switch container {
        case .modifierKeys: self = .modifierKeys
        case .gestures: self = .gestures
        case .defaultShortcuts: self = .defaultShortcuts
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
    /// whole page instead (`ShortcutsPagePartTests`). A shipped
    /// action's row no family lists is an inactive one (#92, #2016).
    @MainActor static func owner(
        of anchor: String,
        expander: ShortcutsFamilyRows,
        bindings: [KeyBinding]
    ) -> ShortcutsPagePart? {
        if let part = catalogOwners[anchor] { return part }
        // An app's pocket key is a navigation row named by its Lua.
        if PocketAppLuaArg.bundleID(of: anchor) != nil { return .pocket }
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
        if bindings.contains(where: {
            $0.kind == .navigation && $0.lua == anchor
        }) {
            return .inactive
        }
        return nil
    }

    /// The part drawing `anchor` and the segment showing it, from the
    /// segment `shown`: the one answer every landing on the page asks
    /// (#3184).
    @MainActor static func placing(
        _ anchor: String,
        expander: ShortcutsFamilyRows,
        bindings: [KeyBinding],
        shown: ShortcutsSegment
    ) -> (part: Self, segment: ShortcutsSegment)? {
        owner(of: anchor, expander: expander, bindings: bindings).map {
            ($0, $0.segment(from: shown))
        }
    }

    /// The part drawing a binding row the recorder names by id.
    private static func owner(of binding: KeyBinding) -> ShortcutsPagePart {
        if PocketAppLuaArg.bundleID(of: binding.lua) != nil { return .pocket }
        switch binding.kind {
        case .application: return .openApplications
        case .custom: return .luaBindings
        case .navigation: return .inactive
        case .sequence: return .keySequences
        }
    }

    /// Catalog controls no census row labels — the cards' own titles,
    /// the sub-headings and drawers inside them — and the Mouse &
    /// Trackpad entries. A control added to the page or moved
    /// between cards is placed here.
    @MainActor private static let catalogOwners: [String: Self] = {
        let catalog = SettingsCatalog.shortcuts
        var owners: [String: Self] = [:]
        for group in ShortcutsJumpGroup.allCases {
            owners[group.control.id] = Self(group)
        }
        let more: [(SettingsControl, Self)] = [
            (catalog.gestures.control, .gestures),
            (catalog.gesturesOnWindows, .gestures),
            (catalog.gesturesModifier, .gestures),
            (catalog.gesturesOnShelf, .gestures),
            (catalog.openApplications, .openApplications),
            (catalog.luaBindings.control, .luaBindings),
            (catalog.modifierKeys.control, .modifierKeys),
            (catalog.layersCard.control, .layers),
            (catalog.keySequencesCard.control, .keySequences),
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

    /// How a reveal reaches `anchor` on the page: through its part
    /// unless the page holds the part built, or by building the whole
    /// page when no part is known to hold it.
    @MainActor static func landing(
        for anchor: String,
        in model: SettingsModel
    ) -> RevealLanding? {
        let layer = model.nav.shortcutsLayerSelection
        let owner = owner(
            of: anchor,
            expander: .ofDraft(model, layer: layer),
            bindings: model.shortcutsLayerBindings
        )
        guard let owner else { return .wholePage }
        if model.shortcutsPage.built.contains(owner) { return nil }
        return .part(owner.id)
    }
}

/// The Shortcuts page's parts built, which a reveal reaches without a
/// detour (#3060). A hint fed by the parts' `onAppear` and
/// `onDisappear` and emptied when the page goes: it can only miss a
/// built part, never claim an unbuilt one, so a reader may skip a
/// detour on it and never the whole-page fallback. Not published, so
/// a write re-renders nothing.
@MainActor
final class ShortcutsPageState {
    var built: Set<ShortcutsPagePart> = []
}
