import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The board's conflict-class surfacing wires (owner rulings
/// 2026-08-10), pinned by needles through the branch bodies —
/// guard-prover reverted both with every suite green before
/// these existed (the Monitors lesson, again): a surfacing
/// decision ends in an `if` inside a `body`, and nothing above
/// it can see the `if` deleted.
@Suite("Keyboard conflict surfacing wires")
struct KeyboardConflictWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let needles: [String: [String]] = [
        "Components/Keybindings/KeyboardBoard.swift": [
            // A conflicted OR overwritten key rings the solid
            // conflict red — the needle runs THROUGH the
            // stroke, so a branch that keeps its condition and
            // stops drawing red reds too (code review
            // 2026-08-10: the first cut ended at `{`).
            "ifisConflicted||isOverwritten{"
                + "RoundedRectangle(cornerRadius:4)"
                + ".strokeBorder(SettingsTheme.keyConflict,"
                + "lineWidth:2)",
            // …and the overwritten set is the census's ONE
            // predicate, never a re-derivation beside it.
            "KeyboardCensus.overwrittenReserved(claims:claims,"
                + "scope:scope)",
        ],
        "Components/Keybindings/KeyboardPreviewPanel.swift": [
            // The red legend entry exists only while a red
            // ring is on the board (the caption rule applied
            // to a legend) — needle through the gate AND the
            // swatch it draws.
            "if!collisions.isEmpty||overwritesReserved{"
                + "lineSwatch(SettingsTheme.keyConflict",
            // The amber entry likewise: gated on a DRAWN
            // dashed ring, not on a chip being picked — ⌃⌥
            // reserves nothing (code review 2026-08-10).
            "if!reservedFree.isEmpty{"
                + "lineSwatch(SettingsTheme.keyReserved",
            // Both gates read the census sets, the board's own
            // predicate.
            "KeyboardCensus.overwrittenReserved(claims:claims,"
                + "scope:liveScope)",
            "KeyboardCensus.reservedUnbound(claims:claims,"
                + "scope:liveScope)",
        ],
    ]

    @Test("the conflict-class wires survive in their bodies")
    func wiresAreDrawn() throws {
        for (file, wants) in Self.needles {
            let url = Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/\(file)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(!wants.isEmpty)
            for want in wants {
                #expect(
                    source.contains(want),
                    Comment(
                        rawValue:
                            "\(file) lost its conflict wire: "
                            + want
                    )
                )
            }
        }
    }
}

/// The behavior half: the census's conflict-class sets, which
/// the needles above pin the views to consuming.
@Suite("Keyboard conflict-class sets")
struct KeyboardConflictSetTests {
    /// ⌘W is `closeWindow` in `SystemShortcuts.map` — the
    /// worked example the ruling used.
    private var commandW: KeyCombo {
        KeyCombo.parse("command+w")!
    }

    @Test("a bound reserved combo is overwritten, not amber")
    func boundReservedIsOverwritten() {
        let scope = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(
                modifiers: commandW.modifiers
            )
        )
        let bound = [
            commandW.keyCode: [
                KeyboardCensus.ModifierLayer(
                    modifiers: commandW.modifiers
                )
            ]
        ]
        let overwritten = KeyboardCensus.overwrittenReserved(
            claims: bound,
            scope: scope
        )
        #expect(overwritten.contains(commandW.keyCode))
        // …and it leaves the amber set the moment it is bound.
        #expect(
            !KeyboardCensus.reservedUnbound(
                claims: bound,
                scope: scope
            ).contains(commandW.keyCode)
        )
        // Unbound, the same key is amber, not overwritten.
        let free = KeyboardCensus.reservedUnbound(
            claims: [:],
            scope: scope
        )
        #expect(free.contains(commandW.keyCode))
        #expect(
            KeyboardCensus.overwrittenReserved(
                claims: [:],
                scope: scope
            ).isEmpty
        )
    }

    @Test("`.all` draws no reserved marks — combos, not keys")
    func allScopeReservesNothing() {
        #expect(
            KeyboardCensus.reservedKeys(scope: .all).isEmpty
        )
    }

    /// The amber PAIR reads one derivation: the `.cantBind`
    /// the board's dashed ring draws and the `reservedUnbound`
    /// its legend entry gates on must agree key for key — two
    /// parallel readings of `SystemShortcuts.map` were
    /// equivalent-by-luck until `state` was routed through
    /// `reservedKeys` (re-review 2026-08-10).
    @Test("the dashed ring and its legend entry agree")
    func amberPairReadsOneDerivation() {
        let scope = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(
                modifiers: commandW.modifiers
            )
        )
        let amber = KeyboardCensus.reservedUnbound(
            claims: [:],
            scope: scope
        )
        #expect(!amber.isEmpty)
        for code in amber {
            #expect(
                KeyboardCensus.state(
                    of: code,
                    claims: [:],
                    scope: scope
                ) == .cantBind
            )
        }
    }
}
