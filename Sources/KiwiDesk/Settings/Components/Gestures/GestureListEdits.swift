import Foundation
import KiwiDeskCore

/// The gesture list's edits over the draft's base map (#3183, #3199
/// ▸ Ruling): a card lists the bound rows of one device, the seeds
/// included as real rows, and every edit writes the sparse map —
/// a seeded key a row leaves is tombstoned, any other key is
/// dropped. Pure, so the card and its tests share one copy.
enum GestureListEdits {
    /// The inputs a card offers: the device's, and only those a front
    /// fires, since an affordance for a channel that does not exist
    /// yet is removed outright (gui.md).
    static func inputs(on device: GestureInput.Device) -> [GestureInput] {
        GestureInput.allCases.filter { $0.device == device && $0.isFired }
    }

    /// The card's rows: every key of the device the base and the
    /// seeds bind, in the list's order (gesture, then keys) — one
    /// Core refuses included, which its row's caption explains. The
    /// card snapshots this on appear and never re-sorts while
    /// editing.
    static func rows(
        in base: GestureMap,
        on device: GestureInput.Device
    ) -> [GestureKey] {
        let offered = Set(inputs(on: device))
        let keys = Set(GestureSeeds.seeds.keys).union(base.entries.keys)
        return keys.filter {
            offered.contains($0.input) && action(of: $0, in: base) != nil
        }
        .sorted()
    }

    /// The card's rows after the map moved under them — a revert, a
    /// Save, a reload: a row whose key is still bound keeps its id
    /// and place, a `pending` row (added, or re-keyed onto a
    /// gesture that dropped its action) stays, any other row whose
    /// key left goes, and a key newly bound joins at the bottom.
    static func reconcile(
        _ entries: [GestureListEntry],
        pending: Set<UUID>,
        in base: GestureMap,
        on device: GestureInput.Device
    ) -> [GestureListEntry] {
        let bound = rows(in: base, on: device)
        let kept = entries.filter {
            bound.contains($0.key) || pending.contains($0.id)
        }
        let held = Set(kept.map(\.key))
        return kept
            + bound.filter { !held.contains($0) }.map {
                GestureListEntry($0)
            }
    }

    /// The action a catalogue pick binds: the command's Lua as a
    /// built-in, read back through `catalog.command(running:)`
    /// (#3199 ▸ Stored value). The row and its guard share it.
    static func action(picking command: NavCommand) -> GestureAction {
        .run(LuaAction(lua: command.lua, kind: .navigation))
    }

    /// The refusal of a click or hover_move whose keys a drag in
    /// `base` holds, which Core drops (`GestureSeeds.resolved`).
    static func heldByDrag(
        _ key: GestureKey,
        in base: GestureMap
    ) -> GestureRefusal? {
        guard key.input == .hoverMove || key.input == .click else {
            return nil
        }
        return GestureSeeds.shadowRefusal(
            of: key,
            base: base,
            profile: nil
        )
    }

    /// What `key` binds once the base lies over the seeds.
    static func action(
        of key: GestureKey,
        in base: GestureMap
    ) -> GestureAction? {
        if let entry = base[key] { return entry.action }
        return GestureSeeds.seeds[key]
    }

    /// Binds `action` at `key`.
    static func set(
        _ action: GestureAction,
        at key: GestureKey,
        in base: inout GestureMap
    ) {
        base[key] = GestureSeeds.seeds[key] == action ? nil : .bound(action)
    }

    /// Removes the row at `key`: a seed's key is tombstoned so the
    /// seed stays off, any other key leaves the map.
    static func remove(_ key: GestureKey, in base: inout GestureMap) {
        base[key] = GestureSeeds.seeds[key] == nil ? nil : .unbound
    }

    /// Moves the row at `from` to `to` (a new gesture or new keys),
    /// keeping its action; nil when `to` already holds a row, which
    /// the recorder refuses and names.
    static func rekey(
        _ from: GestureKey,
        to: GestureKey,
        in base: inout GestureMap
    ) -> Bool {
        guard from != to else { return true }
        guard action(of: to, in: base) == nil,
            let moving = action(of: from, in: base)
        else { return false }
        remove(from, in: &base)
        set(moving, at: to, in: &base)
        return true
    }

    /// Restore Defaults on one card: every seeded key of the device
    /// returns to its seed, and the user's other rows stay.
    static func restoreDefaults(
        on device: GestureInput.Device,
        in base: inout GestureMap
    ) {
        for key in GestureSeeds.seeds.keys where key.input.device == device {
            base[key] = nil
        }
    }

    /// A directional row's arms (#3183 ▸ Ruling: directions of a
    /// family row): a family's are its one-shot steps, pre-filled;
    /// a split's are its own; nil for any other action.
    static func arms(
        of action: GestureAction?,
        on input: GestureInput
    ) -> [GestureDirection: LuaAction]? {
        switch action {
        case .family(let family): prefill(family, on: input)
        case .split(let arms): arms
        default: nil
        }
    }

    /// `family`'s one-shot step toward each of `input`'s directions.
    static func prefill(
        _ family: GestureFamily,
        on input: GestureInput
    ) -> [GestureDirection: LuaAction] {
        Dictionary(
            uniqueKeysWithValues: input.directions.map {
                ($0, LuaAction(lua: family.lua($0), kind: .navigation))
            }
        )
    }

    /// What `arms` save as: the family whose every step they still
    /// match, which keeps the pan, else the arms one by one.
    static func folded(
        _ arms: [GestureDirection: LuaAction],
        on input: GestureInput
    ) -> GestureAction? {
        let lua = arms.mapValues(\.lua)
        if let family = input.families.first(where: { family in
            prefill(family, on: input).mapValues(\.lua) == lua
        }) {
            return .family(family)
        }
        return .split(normalizing: arms)
    }

    /// Whether `device`'s seeded rows differ from the seeds.
    static func differsFromDefaults(
        on device: GestureInput.Device,
        in base: GestureMap
    ) -> Bool {
        GestureSeeds.seeds.keys.contains {
            $0.input.device == device && base[$0] != nil
        }
    }
}
