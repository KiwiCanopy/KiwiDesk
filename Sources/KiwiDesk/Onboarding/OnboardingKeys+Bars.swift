import Foundation
import KiwiDeskCore

/// The bar show/hide chords and the maximize chord the tour
/// teaches (#2515), read from the live layer like every family.
@MainActor
extension OnboardingKeys {
    /// The show/hide verbs, Space Bar first, each with its row
    /// label.
    private static var revealCommands: [NavCommand] {
        [KeybindingCatalog.toggleSpaceBar, KeybindingCatalog.toggleAppBar]
    }

    private static func combo(
        _ command: NavCommand,
        in layer: KeyLayer
    ) -> String? {
        layer.bindings.first {
            $0.lua == command.lua && !$0.combo.isEmpty
        }?.combo
    }

    /// One row per bar whose show/hide verb is bound, in the
    /// catalog's own words — the bars step's list.
    static func revealFamilies(layer: KeyLayer) -> [OnboardingKeyFamily] {
        revealCommands.compactMap { command in
            single(combo: combo(command, in: layer)).map {
                OnboardingKeyFamily(
                    id: command.lua,
                    label: command.resolvedLabel,
                    chord: $0
                )
            }
        }
    }

    /// The keys step's one bar row: both chords collapsed where
    /// both are bound, else the bound one under its own label.
    static func revealFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        let rows = revealFamilies(layer: layer)
        guard rows.count == revealCommands.count else {
            return rows.first
        }
        let combos = revealCommands.compactMap { combo($0, in: layer) }
        guard let chord = collapsed(combos) ?? listed(combos) else {
            return nil
        }
        return OnboardingKeyFamily(
            id: "bars",
            label: L(
                "onboarding.keys.bars",
                "Show or hide the Space Bar or App Bar"
            ),
            chord: chord
        )
    }

    /// The keys step's maximize row.
    static func maximizeFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        single(
            combo: combo(KeybindingCatalog.maximize, in: layer)
        ).map {
            OnboardingKeyFamily(
                id: "maximize",
                label: L(
                    "onboarding.keys.maximize",
                    "Maximize the window"
                ),
                chord: $0
            )
        }
    }
}
