import KiwiDeskCore

/// One gesture drawn on a shortcuts panel row (#1873 ▸ Ruling
/// 2026-11-15, the hybrid): the gesture and its keys, and the way a
/// swipe goes where it runs one direction's action. A whole family
/// on a folded row names no direction.
struct ShortcutGestureBadge: Hashable, Identifiable {
    let key: GestureKey
    let direction: GestureDirection?
    /// What the gesture is called, its way included — read aloud and
    /// matched by a search; worded once, on the main actor.
    let words: String

    @MainActor init(key: GestureKey, direction: GestureDirection?) {
        self.key = key
        self.direction = direction
        let input = GestureListWords.input(key.input)
        words =
            direction.map {
                L(
                    "shortcuts.gestures.direction_action",
                    "%1$@, %2$@",
                    input,
                    GestureListWords.direction($0)
                )
            } ?? input
    }

    var id: String {
        key.spelling + (direction.map { ":" + $0.rawValue } ?? "")
    }

    /// The badge's glyph: a swipe's direction badge (variant A
    /// tightened) where it names a way, else the gesture's own
    /// glyph — a whole family's being today's swipe glyph.
    @MainActor var symbol: String {
        if let direction, let fingers = key.input.fingers,
            !key.input.directions.isEmpty,
            CustomGlyph.badgeDirections.contains(direction),
            (2...4).contains(fingers)
        {
            return CustomGlyph.swipe(fingers, direction).name
        }
        // A rotation's badge turns its way (#1873 ▸ owner 2026-11-15).
        if let direction, key.input == .rotate {
            return GestureListWords.direction(symbol: direction)
        }
        return GestureListWords.symbol(key.input)
    }

    @MainActor var chord: String { ScrollChordGlyphs.text(key.chord) }

    /// The badge as VoiceOver reads it: the keys, then the gesture.
    @MainActor var spoken: String {
        guard !key.chord.isEmpty else { return words }
        return L(
            "shortcuts.gestures.direction_action_chord",
            "%1$@, %2$@, with %3$@",
            GestureListWords.input(key.input),
            direction.map { GestureListWords.direction($0) } ?? "",
            chord
        )
    }

    /// The most specific badge first (#1873 ▸ Ruling 2026-11-15):
    /// the ladder's gesture — a trackpad gesture before a mouse one,
    /// then the fewest keys held, then a swipe before any other
    /// gesture, then the fewest fingers; the rest follow in that
    /// order behind "+N".
    static func moreSpecific(
        _ a: ShortcutGestureBadge,
        _ b: ShortcutGestureBadge
    ) -> Bool {
        let rank = { (badge: ShortcutGestureBadge) -> [Int] in
            let input = badge.key.input
            return [
                input.device == .trackpad ? 0 : 1,
                badge.key.chord.rawValue.nonzeroBitCount,
                input.directions.isEmpty ? 1 : 0,
                input.fingers ?? 9,
            ]
        }
        let (l, r) = (rank(a), rank(b))
        return l != r ? l.lexicographicallyPrecedes(r) : a.id < b.id
    }
}
