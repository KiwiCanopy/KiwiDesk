import Foundation

/// The Sides pull-down's choices (#2614): each sided modifier of a
/// chord or a tap may be put on its left key, its right key or
/// either side, after recording.
extension KeyCombo {
    /// Whether `kind` can keep a side at all: not the modifier one
    /// of whose keys IS the Hyper key, which only the other key can
    /// then make (#2601 ▸ Ruling 4). A Hyper chord is the caller's
    /// to refuse. The recorder and the pull-down both ask it.
    public static func takesSide(
        _ kind: ModifierKind,
        hyperKey: HyperSourceKey?
    ) -> Bool {
        kind != hyperKey?.modifierSide?.kind
    }

    /// The modifiers a side can be picked for; none on a Hyper
    /// chord, which `parse` refuses a side (#2601).
    public func pickableSideKinds(
        hyperKey: HyperSourceKey?
    ) -> [ModifierKind] {
        guard !modifiers.contains(.hyper) else { return [] }
        return ModifierKind.allCases.filter {
            modifiers.contains($0.plain)
                && Self.takesSide($0, hyperKey: hyperKey)
        }
    }

    /// The combo with `kind` on `side`, nil for either side; nil
    /// where the rules refuse it (a tap's are `KeyCombo.tap`'s).
    public func pickingSide(
        _ side: ModifierSide?,
        of kind: ModifierKind,
        hyperKey: HyperSourceKey?
    ) -> KeyCombo? {
        guard pickableSideKinds(hyperKey: hyperKey).contains(kind) else {
            return nil
        }
        if let count = tapCount {
            return KeyCombo.tap(kind, side: side, count: count)
        }
        var out = modifiers
        for each in ModifierSide.allCases {
            out.remove(.side(each, of: kind))
        }
        if let side { out.insert(.side(side, of: kind)) }
        return KeyCombo(keyCode: keyCode, modifiers: out)
    }
}
