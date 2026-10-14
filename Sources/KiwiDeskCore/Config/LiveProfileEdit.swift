import Foundation

/// What a write of the live profile from outside Settings changes
/// (#1518, #1790): the one value the door carries to the
/// file and to an open draft alike, so the two cannot apply
/// different edits.
public enum LiveProfileEdit {
    /// A leaf of the settings — the tour's look, a bar row.
    case settings(SettingsEdit)
    /// A temporary Space added to the profile (#1790).
    case addSpace(SpaceID, AddedSpace)
    /// A Space removed from the profile (#1790).
    case removeSpace(SpaceID)
    /// What `keep_settings` writes (#1685): live leaves and the
    /// layouts of Spaces the profile already declares.
    case kept(KeptLeaves)

    /// Whether the edit moves which Spaces the profile declares,
    /// so the adoption record must follow the file (#1245).
    var redeclares: Bool {
        switch self {
        case .addSpace, .removeSpace: return true
        case .settings, .kept: return false
        }
    }
}

/// The live values a keep writes (#1685): settings leaves by path
/// inside `settings` — nil removes the leaf, so the decoder's
/// default answers — and each kept Space's layout.
public struct KeptLeaves: Equatable {
    public var settings: [[String]: JSONValue?]
    public var spaceModes: [SpaceID: LayoutMode]

    public init(
        settings: [[String]: JSONValue?] = [:],
        spaceModes: [SpaceID: LayoutMode] = [:]
    ) {
        self.settings = settings
        self.spaceModes = spaceModes
    }

    /// Whether the edit writes nothing.
    var isEmpty: Bool { settings.isEmpty && spaceModes.isEmpty }

    /// `settings` with the kept leaves laid over; unchanged where
    /// the decoder refuses the result.
    func applied(to settings: TilingSettings) -> TilingSettings {
        self.settings.isEmpty
            ? settings : settings.patched(self.settings) ?? settings
    }
}

/// Where an added Space goes and what it carries: its place in
/// the list, mode, pin and icon — the fields a Settings row
/// shows (#1790).
public struct AddedSpace: Sendable, Equatable {
    /// The profile Space it follows in live order; nil puts it
    /// first.
    public let after: SpaceID?
    public let mode: LayoutMode
    /// The screen fingerprint it is pinned to, if any.
    public let pin: String?
    public let icon: String?

    public init(
        after: SpaceID?,
        mode: LayoutMode,
        pin: String?,
        icon: String?
    ) {
        self.after = after
        self.mode = mode
        self.pin = pin
        self.icon = icon
    }
}

extension Array where Element == SpaceID {
    /// `self` with `id` placed after `after`, or first.
    fileprivate func inserting(
        _ id: SpaceID,
        after: SpaceID?
    ) -> [SpaceID] {
        var list = filter { $0 != id }
        let found = after.flatMap { list.firstIndex(of: $0) }
        let index = found.map { $0 + 1 } ?? 0
        list.insert(id, at: index)
        return list
    }
}

extension Profile {
    /// Applies `edit` to this profile's file shape; a pin lands in
    /// the set covering `monitors`, if the profile has one.
    public mutating func apply(
        _ edit: LiveProfileEdit,
        monitors: [String]
    ) {
        switch edit {
        case .settings(let change):
            change(&settings)
        case .addSpace(let id, let added):
            spaces = orderedSpaces.inserting(id, after: added.after)
            spaceModes[id] = added.mode
            settings.spaceIcons[id] = added.icon
            if let pin = added.pin, let set = set(matching: monitors) {
                upsert(set.pinning(id, to: pin))
            }
        case .removeSpace(let id):
            spaces.removeAll { $0 == id }
            spaceModes[id] = nil
            mainSpaces.removeAll { $0 == id }
            if fallbackSpace == id { fallbackSpace = nil }
            for set in monitorSets { upsert(set.pinning(id, to: nil)) }
            settings.removeSpace(id)
        case .kept(let leaves):
            settings = leaves.applied(to: settings)
            spaceModes.merge(leaves.spaceModes) { $1 }
        }
    }
}

extension MonitorSet {
    /// This set with `id` pinned to `screen`, or unpinned; the
    /// init keeps only pins to its own monitors.
    fileprivate func pinning(_ id: SpaceID, to screen: String?) -> MonitorSet {
        var map = spaceMonitorMap
        map[id] = screen
        return MonitorSet(monitors: monitors, spaceMonitorMap: map)
    }
}

extension GuiConfig {
    /// Applies `edit` to a Settings draft the same way it applied
    /// to the file.
    public mutating func apply(_ edit: LiveProfileEdit) {
        switch edit {
        case .settings(let change):
            change(&settings)
        case .addSpace(let id, let added):
            spaces = spaces.inserting(id, after: added.after)
            spaceModes[id] = added.mode == .bsp ? nil : added.mode
            spacePins[id] = added.pin
            settings.spaceIcons[id] = added.icon
        case .removeSpace(let id):
            removeSpace(id)
        case .kept(let leaves):
            settings = leaves.applied(to: settings)
            for (id, mode) in leaves.spaceModes {
                spaceModes[id] = mode == .bsp ? nil : mode
            }
        }
    }
}
