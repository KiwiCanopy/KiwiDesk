import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Desktop shortcut families' offer (#1125): withheld behind
/// a drawer until one is bound, opened on arrival once one is.
///
/// Split from `ShortcutsGateTests` at the §2.1 band rather than
/// at the ceiling. Two halves, and the second is the one a
/// `guard-prover` round demanded: the resolver answering
/// correctly reaches no screen on its own, and three separate
/// mutations made every Desktop row vanish with the census, the
/// order lists, the gate and both mounts intact and green
/// (2026-09-04).
@Suite("Desktop shortcuts offer")
struct ShortcutsDesktopOfferTests {
    private func config(layers: [String]) -> GuiConfig {
        var c = GuiConfig()
        c.layers = layers.map { KeyLayer(name: $0) }
        return c
    }

    /// The Desktop offer's boundary (#1125). The seed authors no
    /// Desktop binding, so a fresh install answers "withheld" —
    /// the row is an offer, not a setting.
    @Test("a bound Desktop shortcut brings its families to rest")
    func desktopBindingBoundary() {
        func reason(
            _ bindings: [KeyBinding]
        ) -> ShortcutsGates.InertReason? {
            var config = GuiConfig()
            config.layers = [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: bindings
                )
            ]
            return ShortcutsGates(config: config)
                .inertReason(for: .shortcuts(.focusDesktop))
        }
        func binding(
            _ combo: String,
            _ lua: String
        ) -> KeyBinding {
            KeyBinding(combo: combo, lua: lua, kind: .navigation)
        }
        #expect(reason([]) == .noDesktopBinding)
        // A Space verb is not a Desktop verb — the two families
        // sit side by side in the same group, and the offer must
        // not open on the wrong one.
        #expect(
            reason([binding("ctrl+alt+1", "KiwiDesk.focus_space('1')")])
                == .noDesktopBinding
        )
        #expect(
            reason([
                binding("ctrl+alt+1", "KiwiDesk.focus_desktop(1)")
            ]) == nil
        )
        // …and the two other verbs count for the same offer.
        #expect(
            reason([
                binding(
                    "ctrl+alt+2",
                    "KiwiDesk.move_to_desktop(2)"
                )
            ]) == nil
        )
        // An UNRECORDED row is not a binding: clearing a row
        // deletes it, so an empty combo is one nobody finished.
        #expect(
            reason([binding("", "KiwiDesk.focus_desktop(1)")])
                == .noDesktopBinding
        )
    }

    /// The offer is the AREA's, not the layer's: the rows are per
    /// layer, but a user who bound a Desktop verb anywhere has
    /// met the concept, and hiding the families while they edit
    /// another layer would make the offer flicker under the
    /// strip.
    @Test("a binding in any layer opens the offer")
    func desktopBindingCountsAcrossLayers() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(
                name: "media",
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+3",
                        lua: "KiwiDesk.move_to_desktop_and_follow(3)",
                        kind: .navigation
                    )
                ]
            ),
        ]
        for key: SettingKey in [
            .shortcuts(.focusDesktop), .shortcuts(.moveToDesktop),
            .shortcuts(.moveToDesktopFollow),
        ] {
            #expect(
                ShortcutsGates(config: config)
                    .inertReason(for: key) == nil
            )
        }
    }

    /// A SURFACING gate leaves nothing behind to prove it was
    /// drawn: the resolver's own suite, the census parity and
    /// the family expansion all pass whether or not the `if`
    /// was ever written (the Monitors lesson). So the branches
    /// are needled through their BODIES, keyed on the use site.
    @Test("the Desktop offer draws both of its branches")
    func desktopOfferBranchesAreDrawn() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "Keybindings/DesktopShortcutsOffer.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        // The verdict is the resolver's, never counted here.
        #expect(
            source.contains(
                "ShortcutsGates(config:model.config)"
                    + ".desktopBindingsExist"
            )
        )
        // ONE container in both states — the flip that would
        // otherwise fire while the user records inside it.
        #expect(
            source.contains(
                "SettingsDisclosure(drawer,isExpanded:$expanded,"
                    + "scrollHoisted:true){families}"
            )
        )
        #expect(source.occurrences(of: "SettingsDisclosure(") == 1)
        // …seeded open once bound, never forced shut.
        #expect(
            source.contains(".onAppear{ifbound{expanded=true}}")
        )
        // …and neither draws while the families are empty, or
        // the door opens on nothing.
        #expect(source.contains("ifhasRows{"))
        // The swap is re-introducible by NESTING it inside that
        // guard, and every positive needle above survives it —
        // a substring set cannot see structure (guard-prover,
        // 2026-09-04). So `body` is read as a brace-balanced run
        // and held to ONE branch: one container, drawn once.
        let mark = source.range(of: "varbody:someView")
        var cursor =
            mark.map {
                source.distance(
                    from: source.startIndex,
                    to: $0.upperBound
                )
            } ?? 0
        let characters = Array(source)
        let body =
            SourceScan.balanced(
                characters,
                from: &cursor,
                open: "{",
                close: "}"
            ) ?? ""
        // Vacuity: an empty run satisfies every clause below.
        #expect(!body.isEmpty)
        #expect(
            !body.contains("else"),
            Comment(
                rawValue: "a second arm in the offer's body is "
                    + "the container swap coming back"
            )
        )
        #expect(body.occurrences(of: "families") == 1)
        #expect(body.occurrences(of: "SettingsDisclosure(") == 1)
        // `families` WALKS the keys: a body reduced to an empty
        // view satisfied every needle above while shipping every
        // Desktop row invisible (guard-prover, 2026-09-04).
        #expect(
            source.contains(
                "ForEach(keys,id:\\.id){keyin"
                    + "KeybindingFamilyRows(model:model,"
                    + "bindings:$bindings,key:key,"
                    + "expander:expander,showsHeading:false)"
            )
        )
        // Both groups mount it, with their own family list.
        let groups = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Keybindings/KeybindingGroups.swift"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        #expect(
            groups.occurrences(of: "DesktopShortcutsOffer(") == 2
        )
        // Each mount takes its OWN list and its OWN door: the
        // two drawers swapped left every suite green, heading
        // the Focus card "Move windows to a macOS Desktop" and
        // landing its search anchor in the wrong group
        // (guard-prover, 2026-09-04).
        #expect(
            groups.contains(
                "keys:ShortcutsRowOrder.focusDesktopFamilies,"
                    + "drawer:SettingsCatalog.shortcuts"
                    + ".focusDesktops"
            )
        )
        #expect(
            groups.contains(
                "keys:ShortcutsRowOrder"
                    + ".moveWindowsDesktopFamilies,"
                    + "drawer:SettingsCatalog.shortcuts"
                    + ".moveWindowsDesktops"
            )
        )
    }
}
