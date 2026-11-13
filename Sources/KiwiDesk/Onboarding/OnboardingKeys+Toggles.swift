import Foundation
import KiwiDeskCore

/// The single-key toggles the tour teaches (#2515) — maximize,
/// Tiling Off, Pocket, KiwiVision, and the bars step's show/hide —
/// read from the live layer like every family.
@MainActor
extension OnboardingKeys {
    /// The show/hide verbs, Space Bar first.
    private static var revealCommands: [NavCommand] {
        [KeybindingCatalog.toggleSpaceBar, KeybindingCatalog.toggleAppBar]
    }

    static func combo(
        _ command: NavCommand,
        in layer: KeyLayer
    ) -> String? {
        combo(lua: command.lua, in: layer)
    }

    /// The chord bound to `lua`, nil where it is unbound.
    static func combo(lua: String, in layer: KeyLayer) -> String? {
        layer.bindings.first {
            $0.lua == lua && !$0.combo.isEmpty
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

    /// The keys step's Tiling Off row, in the menu's words (#3287).
    static func tilingOffFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        single(
            combo: combo(KeybindingCatalog.toggleTiling, in: layer)
        ).map {
            OnboardingKeyFamily(
                id: "tiling_off",
                label: KeybindingCatalog.toggleTiling.resolvedLabel,
                chord: $0
            )
        }
    }

    /// The keys step's Pocket row (#2446, the tenth by owner
    /// ruling 2026-10-23).
    static func pocketFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        single(
            combo: combo(KeybindingCatalog.pocket, in: layer)
        ).map {
            OnboardingKeyFamily(
                id: "pocket",
                label: L(
                    "onboarding.keys.pocket",
                    "Pocket a window, then take it out from anywhere"
                ),
                chord: $0
            )
        }
    }

    /// The keys step's KiwiVision row, saying what a press does
    /// for a reader who has not met the word.
    static func kiwiVisionFamily(layer: KeyLayer) -> OnboardingKeyFamily? {
        single(
            combo: combo(KeybindingCatalog.toggleKiwiVision, in: layer)
        ).map {
            OnboardingKeyFamily(
                id: "kiwivision",
                label: L(
                    "onboarding.keys.kiwivision",
                    "KiwiVision: dim everything else"
                ),
                chord: $0
            )
        }
    }
}
