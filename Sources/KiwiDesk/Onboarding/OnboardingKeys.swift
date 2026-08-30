import Foundation
import KiwiDeskCore

/// Derives chord families taught during onboarding from the live
/// key layer (#678).
@MainActor
enum OnboardingKeys {
    static func families(
        layer: KeyLayer,
        spaces: [SpaceID]
    ) -> [OnboardingKeyFamily] {
        var families: [OnboardingKeyFamily] = []
        if let focus = directional(
            layer: layer,
            command: "focus"
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "focus",
                    label: L(
                        "onboarding.keys.focus",
                        "Move focus"
                    ),
                    chord: focus,
                    tier: .movesFocus
                )
            )
        }
        if let swap = directional(layer: layer, command: "swap") {
            families.append(
                OnboardingKeyFamily(
                    id: "swap",
                    label: L(
                        "onboarding.keys.swap",
                        "Swap the window"
                    ),
                    chord: swap,
                    tier: .movesWindow
                )
            )
        }
        if let go = digits(
            layer: layer,
            command: "focus_space",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "focus_space",
                    label: L(
                        "onboarding.keys.go_to_space",
                        "Go to a Space"
                    ),
                    chord: go,
                    tier: .movesFocus
                )
            )
        }
        if let move = digits(
            layer: layer,
            command: "move_to_space",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "move_to_space",
                    label: L(
                        "onboarding.keys.move_to_space",
                        "Move the window to a Space"
                    ),
                    chord: move,
                    tier: .movesWindow
                )
            )
        }
        if let follow = digits(
            layer: layer,
            command: "move_to_space_and_follow",
            spaces: spaces
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "move_to_space_and_follow",
                    label: L(
                        "onboarding.keys.move_and_follow",
                        "Move the window to a Space and follow it"
                    ),
                    chord: follow
                )
            )
        }
        if let panel = single(
            combo: layer.bindings.first {
                $0.lua == ShortcutsOpenBinding.lua
            }?.combo
        ) {
            families.append(
                OnboardingKeyFamily(
                    id: "shortcuts",
                    label: L(
                        "onboarding.keys.all",
                        "See every shortcut"
                    ),
                    chord: panel,
                    isGateway: true
                )
            )
        }
        return families
    }

    /// Derives the modifier tier rule sentence from live chords (#1016).
    static func tierAnchor(
        _ rows: [OnboardingKeyFamily]
    ) -> String? {
        guard let base = sharedModifiers(rows, of: .movesFocus),
            let moves = sharedModifiers(rows, of: .movesWindow),
            // Requires non-empty base modifiers without Shift
            // (OnboardingTierAnchorTests).
            !base.isEmpty,
            !base.contains(.shift),
            moves == base.union(.shift)
        else { return nil }
        return L(
            "onboarding.keys.tier",
            "%1$@ moves your focus. Add %2$@ to move the window.",
            ComboSymbols.modifierSymbols(base),
            ComboSymbols.modifierSymbols(.shift)
        )
    }

    /// Returns the shared modifier set across all families in `tier`,
    /// if uniform.
    private static func sharedModifiers(
        _ rows: [OnboardingKeyFamily],
        of tier: OnboardingKeyTier
    ) -> HotkeyModifiers? {
        let members = rows.filter { $0.tier == tier }
        let sets = members.compactMap { row -> HotkeyModifiers? in
            guard case .shared(let modifiers, _) = row.chord
            else { return nil }
            return modifiers
        }
        guard let first = sets.first,
            sets.count == members.count,
            sets.allSatisfy({ $0 == first })
        else { return nil }
        return first
    }
}
