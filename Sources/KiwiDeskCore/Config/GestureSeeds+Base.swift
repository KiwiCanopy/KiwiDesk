import Foundation

/// Gesture keys on the "Shortcuts use" base (#3444): the seeds sit
/// on the stored `ShortcutBase`, and the switch moves a stored row
/// with the keyboard rows' mapping. The ruling is
/// `docs/design-decisions.md` ▸ *One switch puts KiwiDesk's
/// shortcuts on `⌃⌥` or on `✦`*.
extension ShortcutBase {
    private static let standardChord: ScrollChord = [.control, .option]
    private static let keptChord: ScrollChord = [.shift, .command]

    /// `chord` moved onto `base`, or nil where the mapping does not
    /// cover it — `moved(_:to:)`'s rule without the Desktop tier,
    /// which no gesture holds: onto `✦`, `⌃⌥` plus at most `⇧` and
    /// `⌘`; onto `⌃⌥`, `✦` plus at most `⇧` and `⌘`.
    public static func moved(
        _ chord: ScrollChord,
        to base: ShortcutBase
    ) -> ScrollChord? {
        switch base {
        case .hyper:
            guard chord.isSuperset(of: standardChord),
                !chord.contains(.hyper)
            else { return nil }
            let rest = chord.subtracting(standardChord)
            return keptChord.isSuperset(of: rest) ? rest.union(.hyper) : nil
        case .standard:
            guard chord.contains(.hyper) else { return nil }
            let rest = chord.subtracting(.hyper)
            return keptChord.isSuperset(of: rest)
                ? rest.union(standardChord) : nil
        }
    }

    /// `key` moved onto `base`, or nil where its keys stay.
    public static func moved(
        _ key: GestureKey,
        to base: ShortcutBase
    ) -> GestureKey? {
        moved(key.chord, to: base).map { GestureKey(key.input, $0) }
    }

    /// `key` on this base: moved where the mapping covers it.
    public func rebased(_ key: GestureKey) -> GestureKey {
        Self.moved(key, to: self) ?? key
    }
}

extension GestureSeeds {
    private static let hyperSeeds = Dictionary(
        uniqueKeysWithValues: standardSeeds.map {
            (ShortcutBase.hyper.rebased($0.key), $0.value)
        }
    )

    /// The seeds on `base`: the shipped table, every key the
    /// mapping covers moved onto it.
    public static func seeds(
        on base: ShortcutBase
    ) -> [GestureKey: GestureAction] {
        switch base {
        case .standard: standardSeeds
        case .hyper: hyperSeeds
        }
    }
}
