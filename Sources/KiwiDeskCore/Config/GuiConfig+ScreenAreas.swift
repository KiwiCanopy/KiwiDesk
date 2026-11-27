import Foundation

/// The key rewrite one merge owes (#3517 ruling 22): every stored
/// reference to the area that vanished moves to the area that
/// absorbed it, which is physically the same place. Keyed by screen
/// number (#3647 ▸ lane 3); a map still keyed by fingerprint takes
/// `runtime(in:)`.
public struct ScreenAreaRemap: Equatable, Sendable {
    public let vanished: ScreenSlotKey
    public let survivor: ScreenSlotKey

    /// Moves `map`'s vanished entry onto the survivor, which keeps
    /// its own entry where it has one.
    public func move<Value>(in map: inout [String: Value]) {
        Self.move(vanished.description, to: survivor.description, in: &map)
    }

    /// This remap on the screen `order` gives its number, keyed by
    /// fingerprint; nil where no screen holds it.
    public func runtime(in order: ScreenOrder) -> Fingerprinted? {
        guard let old = order.runtimeKey(of: vanished),
            let new = order.runtimeKey(of: survivor)
        else { return nil }
        return Fingerprinted(vanished: old, survivor: new)
    }

    /// A remap keyed by fingerprint, for the runtime and the maps
    /// that lane 3c moves to numbers.
    public struct Fingerprinted: Equatable, Sendable {
        public let vanished: ScreenAreaKey
        public let survivor: ScreenAreaKey

        /// `key` as it reads after the merge.
        public func rewrite(_ key: String) -> String {
            ScreenAreaKey(parsing: key) == vanished
                ? survivor.description : key
        }

        /// As `ScreenAreaRemap.move(in:)`.
        public func move<Value>(in map: inout [String: Value]) {
            ScreenAreaRemap.move(
                vanished.description,
                to: survivor.description,
                in: &map
            )
        }
    }

    static func move<Value>(
        _ old: String,
        to new: String,
        in map: inout [String: Value]
    ) {
        guard let moved = map.removeValue(forKey: old) else { return }
        if map[new] == nil { map[new] = moved }
    }
}

extension GuiConfig {
    /// Merges areas `a` and `b` of the screen `fingerprint` in this
    /// config and rewrites every key-bearing field through `apply`
    /// — the one door a merge takes. Nil, changing nothing, where
    /// the screen has no number, no such split, or the two share no
    /// full edge.
    @discardableResult
    public mutating func mergeAreas(
        _ a: Int,
        _ b: Int,
        on fingerprint: String,
        order: ScreenOrder
    ) -> ScreenAreaRemap? {
        guard let number = order.number(of: fingerprint),
            let merged = settings.displayAreas
                .split(on: fingerprint, order: order)?
                .merging(a, b)
        else { return nil }
        settings.displayAreas.store(
            merged.split,
            on: fingerprint,
            order: order
        )
        guard
            let vanished = ScreenSlotKey(
                number: number,
                areaID: merged.vanished
            ),
            let survivor = ScreenSlotKey(
                number: number,
                areaID: merged.survivor
            )
        else { return nil }
        let remap = ScreenAreaRemap(vanished: vanished, survivor: survivor)
        apply(remap, order: order)
        return remap
    }

    /// Rewrites every field that stores an area key: the Screen
    /// pins, the areas' Desktop memory and the per-screen maps in
    /// the settings and the shared look
    /// (`ScreenAreaRemapParityTests` finds them by reflection). The
    /// maps still keyed by fingerprint take the screen `order`
    /// gives the number.
    public mutating func apply(
        _ remap: ScreenAreaRemap,
        order: ScreenOrder
    ) {
        for (space, pin) in spacePins where pin == remap.vanished {
            spacePins[space] = remap.survivor
        }
        for (desktop, var shown) in desktopAreaSpaces {
            remap.move(in: &shown)
            desktopAreaSpaces[desktop] = shown
        }
        guard let runtime = remap.runtime(in: order) else { return }
        settings.apply(runtime)
        look?.apply(runtime)
    }
}

extension LookBody {
    /// The shared look's half: a per-screen styling value (the bars'
    /// and the pocket's `edge_override`) is a JSON object keyed by
    /// screen, its vanished entry moved as `ScreenEdged.moveScreen`
    /// moves the settings' own.
    public mutating func apply(_ remap: ScreenAreaRemap.Fingerprinted) {
        let old = remap.vanished.description
        let new = remap.survivor.description
        for (path, value) in style {
            guard case .object(var entries) = value,
                let moved = entries.removeValue(forKey: old)
            else { continue }
            if entries[new] == nil { entries[new] = moved }
            style[path] = .object(entries)
        }
    }
}

extension TilingSettings {
    /// The per-screen maps' half of a merge's rewrite: both bars'
    /// and the pocket's edges, and both bars' Show.
    public mutating func apply(_ remap: ScreenAreaRemap.Fingerprinted) {
        let old = remap.vanished.description
        let new = remap.survivor.description
        spaceBarStyle.moveScreen(old, to: new)
        appBarStyle.moveScreen(old, to: new)
        kiwishelf.pocketEdges.moveScreen(old, to: new)
        Self.move(old, to: new, in: &spaceBarStyle.visibilityOverride)
        eachAppBarVisibilityMap { Self.move(old, to: new, in: &$0) }
    }

    /// A merged-away area's Show moved to the area that absorbed it
    /// where that area has none of its own, as `moveScreen` moves an
    /// edge (ruling 22).
    private static func move(
        _ old: String,
        to new: String,
        in map: inout [String: ShelfVisibility]
    ) {
        guard let moved = map.removeValue(forKey: old) else { return }
        if map[new] == nil { map[new] = moved }
    }
}
