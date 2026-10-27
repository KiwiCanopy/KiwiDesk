import Foundation
import KiwiDeskCore

/// The single-key toggles the tour teaches (#2515) — maximize,
/// KiwiVision and the bars' show/hide — read from the live layer
/// like every family.
@MainActor
extension OnboardingKeys {
    /// The show/hide verbs, Space Bar first, with the bar each
    /// shows.
    private static var revealCommands: [(NavCommand, ShelfBar)] {
        [
            (KeybindingCatalog.toggleSpaceBar, .space),
            (KeybindingCatalog.toggleAppBar, .app),
        ]
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
    static func revealFamilies(
        layer: KeyLayer,
        showsBar: (ShelfBar) -> Bool = { _ in true }
    ) -> [OnboardingKeyFamily] {
        revealCommands.compactMap { command, bar in
            guard showsBar(bar) else { return nil }
            return single(combo: combo(command, in: layer)).map {
                OnboardingKeyFamily(
                    id: command.lua,
                    label: command.resolvedLabel,
                    chord: $0
                )
            }
        }
    }

    /// The keys step's one bar row: both chords collapsed where
    /// both are taught, else the one left under its own label.
    /// `showsBar` leaves out a bar its shortcut cannot show — one
    /// set to Always (owner, 2026-10-23).
    static func revealFamily(
        layer: KeyLayer,
        showsBar: (ShelfBar) -> Bool = { _ in true }
    ) -> OnboardingKeyFamily? {
        let rows = revealFamilies(layer: layer, showsBar: showsBar)
        guard rows.count == revealCommands.count else {
            return rows.first
        }
        let combos = revealCommands.compactMap { combo($0.0, in: layer) }
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
