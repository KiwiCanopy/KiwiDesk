import KiwiDeskCore

/// One gesture drawn on a shortcuts panel row (#1873 ▸ Ruling
/// 2026-11-15, the hybrid): the gesture and its keys, and the way a
/// swipe goes where it runs one direction's action. A whole family
/// on a folded row names no direction.
struct ShortcutGestureBadge: Hashable, Identifiable {
    /// The one axis a family reaches a row along both ways of
    /// (#3380): its badge draws two opposed arrows.
    enum Axis: Hashable {
        case horizontal, vertical

        /// The axis `ways` span exactly; nil for one way, four, or
        /// any other mix.
        static func of(_ ways: Set<GestureDirection>) -> Axis? {
            switch ways {
            case [.left, .right]: .horizontal
            case [.up, .down]: .vertical
            default: nil
            }
        }
    }

    let key: GestureKey
    let direction: GestureDirection?
    /// Set only with no `direction`, for a two-way family.
    var axis: Axis? = nil
    /// What the gesture is called, its way included — read aloud and
    /// matched by a search; worded once, on the main actor.
    let words: String

    @MainActor init(
        key: GestureKey,
        direction: GestureDirection?,
        axis: Axis? = nil
    ) {
        self.key = key
        self.direction = direction
        self.axis = direction == nil ? axis : nil
        let input = GestureListWords.input(key.input)
        words =
            Self.way(direction, self.axis).map {
                L(
                    "shortcuts.gestures.direction_action",
                    "%1$@, %2$@",
                    input,
                    $0
                )
            } ?? input
    }

    /// The way a badge names: its direction, or either of its axis's
    /// ("Left or right", #3380), one phrase per axis so no locale
    /// bends a standalone direction word; nil for no way.
    @MainActor static func way(
        _ direction: GestureDirection?,
        _ axis: Axis?
    ) -> String? {
        if let direction { return GestureListWords.direction(direction) }
        switch axis {
        case .horizontal:
            return L(
                "shortcuts.gestures.axis_ways.left_right",
                "Left or right"
            )
        case .vertical:
            return L("shortcuts.gestures.axis_ways.up_down", "Up or down")
        case nil:
            return nil
        }
    }

    /// The one badge for `key` reaching an action along `ways`: its
    /// way where there is one, its axis where both ways of one axis
    /// reach it (#3380), else no way. KiwiHub and the tour both draw
    /// through it (#3427).
    @MainActor static func covering(
        _ key: GestureKey,
        ways: Set<GestureDirection>
    ) -> ShortcutGestureBadge {
        guard ways.count > 1 else {
            return ShortcutGestureBadge(key: key, direction: ways.first)
        }
        return ShortcutGestureBadge(key: key, direction: nil, axis: .of(ways))
    }

    var id: String {
        key.spelling + (direction.map { ":" + $0.rawValue } ?? "")
    }

    /// The badge's glyph: a swipe's direction badge (variant A
    /// tightened) where it names a way, its axis badge where a family
    /// runs both ways of one axis (#3380), else the gesture's own
    /// glyph — a four-way family's being today's swipe glyph.
    @MainActor var symbol: String {
        if let axis, let fingers = key.input.fingers,
            !key.input.directions.isEmpty,
            CustomGlyph.badgeFingers.contains(fingers)
        {
            return CustomGlyph.swipeAxis(
                fingers,
                vertical: axis == .vertical
            ).name
        }
        if let direction, let fingers = key.input.fingers,
            !key.input.directions.isEmpty,
            CustomGlyph.badgeDirections.contains(direction),
            CustomGlyph.badgeFingers.contains(fingers)
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
        guard let way = Self.way(direction, axis) else {
            return L(
                "shortcuts.gestures.input_chord",
                "%1$@, with %2$@",
                GestureListWords.input(key.input),
                ScrollChordGlyphs.spoken(key.chord)
            )
        }
        return L(
            "shortcuts.gestures.direction_action_chord",
            "%1$@, %2$@, with %3$@",
            GestureListWords.input(key.input),
            way,
            ScrollChordGlyphs.spoken(key.chord)
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
