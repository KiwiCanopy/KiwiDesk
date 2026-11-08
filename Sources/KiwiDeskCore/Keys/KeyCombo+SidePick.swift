import Foundation

/// The Sides pull-down's choices (#2614): each sided modifier of a
/// chord or a tap may be put on its left key, its right key or
/// either side, after recording.
extension KeyCombo {
    /// The modifiers a side can be picked for: none under Hyper,
    /// which registers bare and takes no side (#2601).
    public var pickableSideKinds: [ModifierKind] {
        guard !modifiers.contains(.hyper) else { return [] }
        return ModifierKind.allCases.filter {
            modifiers.contains($0.plain)
        }
    }

    /// The combo with `kind` on `side`, nil for either side; nil
    /// where the rules refuse it — a single tap names a side.
    public func pickingSide(
        _ side: ModifierSide?,
        of kind: ModifierKind
    ) -> KeyCombo? {
        guard pickableSideKinds.contains(kind) else { return nil }
        if tapCount == 1, side == nil { return nil }
        var out = modifiers
        for each in ModifierSide.allCases {
            out.remove(.side(each, of: kind))
        }
        if let side { out.insert(.side(side, of: kind)) }
        return KeyCombo(keyCode: keyCode, modifiers: out)
    }
}
