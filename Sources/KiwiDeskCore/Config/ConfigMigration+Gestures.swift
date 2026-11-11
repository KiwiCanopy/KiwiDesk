import Foundation

/// Mouse and trackpad gestures become one list of bindings (#3199,
/// `GestureMigrationTests`): `trackpad_gesture`'s slots,
/// `modifier_drag`'s move and resize (a press-started grab a
/// `drag` row, a key-started one a `hover_move` row) and
/// `scroll_gesture`'s `pan` and `space_step` fold into the sparse
/// `gesture` map, each keyed by input and keys, and the old keys
/// leave the file. The pan becomes three rows, a phased swipe and
/// a wheel per axis (#3200), and so does the Space step. A value
/// that differs from the seed tombstones the seed's key beside its
/// own row, since the map lies over the seeds.
/// A profile cannot read `gui.json`, so its override tombstones the
/// SEED's key, never the base's: where the base also moved off the
/// seed, the base's row fires in that profile too — the trade the
/// design entry states. Reaches `gui.json`, a profile root and a
/// bundle's `config` and `profiles[]`.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let gestureKey = "gesture"
    static let retiredTrackpadKey = "trackpad_gesture"
    static let retiredDragKey = "modifier_drag"
    static let retiredScrollKey = "scroll_gesture"
    static let profileMonitorSetsKey = "monitor_sets"

    /// The shipped defaults the old keys fell back to.
    static let seededPan = "control+option"
    static let seededStep = "control+option+command"
    static let seededMove = "control+command"
    static let seededResize = "control+option"

    /// Idempotent by construction: it ends the old keys, so a file
    /// already crossed has nothing left to fold.
    @Sendable
    static func migratingGesturesIntoBindings(_ data: Data) -> Data? {
        let needles = [
            retiredTrackpadKey, retiredDragKey, "\"pan\"",
            "space_step",
        ]
        .map { Data($0.utf8) }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: withGestureBindings,
            editing: { _ in nil }
        )
    }

    /// The root itself, a bundle's `config` and each inline profile.
    static func withGestureBindings(_ node: Any) -> (Any, Bool) {
        guard var root = node as? [String: Any] else {
            return (node, false)
        }
        // A profile root carries `monitor_sets`; gui.json does not.
        var changed = foldGestures(
            &root,
            inProfile: root[profileMonitorSetsKey] != nil
        )
        if var config = root["config"] as? [String: Any],
            foldGestures(&config, inProfile: false)
        {
            root["config"] = config
            changed = true
        }
        if var profiles = root[barEdgeProfilesKey] as? [[String: Any]] {
            var did = false
            for index in profiles.indices
            where foldGestures(&profiles[index], inProfile: true) {
                did = true
            }
            if did {
                root[barEdgeProfilesKey] = profiles
                changed = true
            }
        }
        return (root, changed)
    }

    /// A stored chord in the one spelling a gesture key takes: the
    /// old decoders read aliases and any order, and two spellings
    /// of one key would collide.
    static func canonicalChord(_ text: String) -> String {
        ScrollChord(spelling: text)?.spelling ?? text
    }

    /// One object's fold; true where it changed. A profile stored
    /// the pan or the Space step only where it differed from the
    /// base, so its value is written whole even on the seed's keys.
    static func foldGestures(
        _ object: inout [String: Any],
        inProfile: Bool
    ) -> Bool {
        var map = object[gestureKey] as? [String: Any] ?? [:]
        var changed = false
        if let slots = object.removeValue(forKey: retiredTrackpadKey)
            as? [String: Any]
        {
            foldTrackpadSlots(slots, into: &map)
            changed = true
        }
        if let drags = object.removeValue(forKey: retiredDragKey)
            as? [String: Any]
        {
            foldDrag(drags["move"], "move", seededMove, &map)
            foldDrag(drags["resize"], "resize", seededResize, &map)
            changed = true
        }
        if var scroll = object[retiredScrollKey] as? [String: Any] {
            for key in ["pan", "space_step"] {
                if let chord = scroll[key] as? String {
                    scroll[key] = canonicalChord(chord)
                }
            }
            // The old resolve kept the pan where both named one chord.
            if let pan = scroll["pan"] as? String,
                scroll["space_step"] as? String == pan, !pan.isEmpty
            {
                scroll["space_step"] = ""
            }
            for (key, family, seed) in [
                ("pan", "focus", seededPan),
                ("space_step", "space", seededStep),
            ] {
                guard let chord = scroll.removeValue(forKey: key) as? String
                else { continue }
                foldScroll(
                    chord,
                    family: family,
                    seed: seed,
                    inProfile: inProfile,
                    &map
                )
                changed = true
            }
            object[retiredScrollKey] = scroll
        }
        if changed { object[gestureKey] = map }
        return changed
    }

    /// A slot's row: its keys from `modifiers`, a swipe's family or
    /// another slot's Lua. A slot with keys tombstones the seed of
    /// the bare slot it replaced.
    static func foldTrackpadSlots(
        _ slots: [String: Any],
        into map: inout [String: Any]
    ) {
        for (slot, value) in slots {
            guard let binding = value as? [String: Any] else {
                map[slot] = NSNull()
                continue
            }
            let keys = canonicalChord(binding["modifiers"] as? String ?? "")
            let key = keys.isEmpty ? slot : "\(slot):\(keys)"
            if let family = binding["family"] as? String {
                map[key] = ["family": family]
            } else if let lua = binding["lua"] as? String {
                map[key] = ["lua": lua, "kind": "custom"]
            }
            if key != slot { map[slot] = NSNull() }
        }
    }

    /// A move or resize's row: `drag` where it started on a press,
    /// `hover_move` where it started on the keys alone. Either seed
    /// is a `drag` row, tombstoned where the value left it.
    static func foldDrag(
        _ value: Any?,
        _ grab: String,
        _ seed: String,
        _ map: inout [String: Any]
    ) {
        guard let binding = value as? [String: Any] else { return }
        let chord = canonicalChord(binding["modifiers"] as? String ?? seed)
        let hover = binding["start"] as? String == "hover"
        guard chord != seed || hover else { return }
        // The other grab may already have moved onto this seed.
        if map["drag:\(seed)"] == nil { map["drag:\(seed)"] = NSNull() }
        guard !chord.isEmpty else { return }
        let input = hover ? "hover_move" : "drag"
        map["\(input):\(chord)"] = ["grab": grab]
    }

    /// The pan or the Space step: a swipe row and a wheel row for
    /// each axis, as 4.2.x read a tilt wheel. The pan's wheels walk
    /// the list (#3200). The seed's tombstone never lands on a row
    /// the other gesture already moved onto it.
    static func foldScroll(
        _ chord: String,
        family: String,
        seed: String,
        inProfile: Bool,
        _ map: inout [String: Any]
    ) {
        guard chord != seed || inProfile else { return }
        let wheelFamily = family == "focus" ? "walk" : family
        if chord != seed {
            for input in ["swipe2", "wheel", "wheel_x"]
            where map["\(input):\(seed)"] == nil {
                map["\(input):\(seed)"] = NSNull()
            }
        }
        guard !chord.isEmpty else { return }
        map["swipe2:\(chord)"] = ["family": family]
        map["wheel:\(chord)"] = ["family": wheelFamily]
        map["wheel_x:\(chord)"] = ["family": wheelFamily]
    }
}
