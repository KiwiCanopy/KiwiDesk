import Foundation

/// A stored `reveal_duration` or `expand_duration` of 0 or below —
/// what the old decoder read as instant — becomes its
/// toggle off plus the default duration (#3236,
/// `InstantDurationMigrationTests`): 0 left both bands, and the
/// decoder now clamps it to the floor, so without the step a shelf
/// set to instant would start animating. Two families of key, both
/// matched by KEY at any depth: the field inside a profile's
/// `animations` object and the look path a look's `style` map is
/// keyed by — in a profile's own look, `gui.json`'s shared look,
/// `looks.json` and a bundle's inline copies of all of them.
///
/// Gated by the format it introduced (`instantDurationFormats`), a
/// meaning change's obligation (profiles.md).
extension ConfigMigration {
    /// One duration and the toggle that now says "instant".
    struct InstantDuration {
        let duration: String
        let toggle: String
        let fallback: Int
    }

    /// Spelled rather than derived, as #1020's: a historical step
    /// keeps emitting the names and defaults it was written to.
    static let instantDurations: [InstantDuration] = [
        InstantDuration(
            duration: "reveal_duration",
            toggle: "on_reveal",
            fallback: 300
        ),
        InstantDuration(
            duration: "expand_duration",
            toggle: "on_expand",
            fallback: 750
        ),
        InstantDuration(
            duration: "animations.reveal_duration",
            toggle: "animations.on_reveal",
            fallback: 300
        ),
        InstantDuration(
            duration: "animations.expand_duration",
            toggle: "animations.on_expand",
            fallback: 750
        ),
    ]

    /// The formats this step introduced, spelled as history: a file
    /// at or above its shape's stands down, so the step never reads
    /// the app-wide `animations` group `gui.json` gained after it
    /// (#3237), and a 0 typed into a current file stays the floor.
    static let instantDurationFormats: [FileShape: Int] = [
        .profile: 37, .gui: 22, .looks: 4, .bundle: 46,
    ]

    /// Whether `data` is below the format this step introduced for
    /// its shape. An unreadable root stands down.
    static func instantDurationsApply(to data: Data) -> Bool {
        guard
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let floor = instantDurationFormats[shape(of: root)]
        else { return false }
        return (root["format"] as? Int ?? 0) < floor
    }

    @Sendable
    static func migratingInstantDurationsOntoToggles(
        _ data: Data
    ) -> Data? {
        guard instantDurationsApply(to: data) else { return nil }
        let needles = instantDurations.map {
            Data("\"\($0.duration)\"".utf8)
        }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: withInstantDurationsCrossed,
            editing: surgicallyCrossingInstantDurations
        )
    }

    /// Whether `value` is a JSON number at or below 0 — never a Bool,
    /// which `JSONSerialization` also bridges to `NSNumber`.
    static func isStoredInstant(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID()
        else { return false }
        return number.doubleValue <= 0
    }

    /// A look path that is new with the step: an older look's style
    /// map carries a reveal length but no switch, and its absence
    /// meant "the reveal plays" (profiles.md, an absence is a
    /// value), so a look that animates keeps animating over a
    /// profile the step turned off.
    static let lookRevealDuration = "animations.reveal_duration"
    static let lookRevealToggle = "animations.on_reveal"

    /// Whether `dict` is a look style map with an in-band reveal
    /// length and no switch beside it.
    static func lookLacksRevealToggle(_ dict: [String: Any]) -> Bool {
        guard let length = dict[lookRevealDuration],
            dict[lookRevealToggle] == nil
        else { return false }
        return length is NSNumber && !isStoredInstant(length)
    }

    /// The walk: every object carrying an instant duration takes the
    /// fallback and its toggle off.
    static func withInstantDurationsCrossed(_ node: Any) -> (Any, Bool) {
        if var dict = node as? [String: Any] {
            var changed = false
            for entry in instantDurations
            where isStoredInstant(dict[entry.duration]) {
                dict[entry.duration] = entry.fallback
                dict[entry.toggle] = false
                changed = true
            }
            if lookLacksRevealToggle(dict) {
                dict[lookRevealToggle] = true
                changed = true
            }
            for (key, value) in dict {
                let (child, did) = withInstantDurationsCrossed(value)
                guard did else { continue }
                dict[key] = child
                changed = true
            }
            return (dict, changed)
        }
        if let array = node as? [Any] {
            var changed = false
            let out = array.map { value -> Any in
                let (child, did) = withInstantDurationsCrossed(value)
                changed = changed || did
                return child
            }
            return (out, changed)
        }
        return (node, false)
    }

    /// The textual edit, judged against the walk by
    /// `surgicallyApplying`: each instant duration's literal becomes the
    /// fallback, and its object's toggle becomes `false` — the
    /// toggle's own literal where the object states one, else a
    /// new entry right after the duration.
    static func surgicallyCrossingInstantDurations(
        _ text: String
    ) -> Data? {
        let entries = JSONKeyLexer.entries(in: text)
        var edits: [(range: Range<Int>, with: String)] = []
        for entry in instantDurations {
            for duration in entries
            where duration.key == entry.duration
                && (Double(duration.value) ?? 1) <= 0
            {
                let toggle = entries.first {
                    $0.key == entry.toggle
                        && $0.object == duration.object
                }
                if let toggle {
                    edits.append((duration.valueRange, "\(entry.fallback)"))
                    edits.append((toggle.valueRange, "false"))
                } else {
                    edits.append(
                        (
                            duration.valueRange,
                            "\(entry.fallback), \"\(entry.toggle)\": false"
                        )
                    )
                }
            }
        }
        for duration in entries
        where duration.key == lookRevealDuration
            && (Double(duration.value) ?? 0) > 0
            && !entries.contains(where: {
                $0.key == lookRevealToggle && $0.object == duration.object
            })
        {
            edits.append(
                (
                    duration.valueRange,
                    "\(duration.value), \"\(lookRevealToggle)\": true"
                )
            )
        }
        guard !edits.isEmpty else { return nil }
        var bytes = Array(text.utf8)
        let backToFront = edits.sorted {
            $0.range.lowerBound > $1.range.lowerBound
        }
        for edit in backToFront {
            bytes.replaceSubrange(edit.range, with: Array(edit.with.utf8))
        }
        return Data(bytes)
    }
}
