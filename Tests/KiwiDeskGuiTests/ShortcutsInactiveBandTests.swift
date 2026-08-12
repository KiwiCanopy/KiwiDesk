import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The panel's Inactive band (#820): a binding whose target Space
/// has left the current list is surfaced under its real name in a
/// band of its own, instead of falling through to Custom as raw
/// Lua — the band that means "user-authored", which a seeded
/// digit shortcut never was. The predicate is Settings' own
/// (`OrphanedShortcuts`, #92), so the two surfaces cannot
/// disagree about what is inactive. Split from
/// `ShortcutsReferenceTests` for the file ceiling; `.serialized`
/// for the same reason it is (`LocalizationManager` is
/// process-wide).
@Suite("Shortcuts panel inactive band", .serialized)
@MainActor
struct ShortcutsInactiveBandTests {
    private func reset() {
        LocalizationManager.shared.select("en")
    }

    private func binding(
        _ combo: String,
        _ lua: String
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation)
    }

    private func build(
        _ bindings: [KeyBinding],
        spaces: [SpaceID] = [SpaceID("1")]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings
            ),
            spaces: spaces,
            spaceIcons: [:],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    @Test("a deleted Space's shortcut reads as itself, not Lua")
    func orphanCarriesItsRealName() {
        reset()
        let reference = build([
            binding("ctrl+alt+6", "KiwiDesk.focus_space(\"6\")")
        ])
        #expect(reference.custom.isEmpty)
        #expect(reference.inactive.count == 1)
        let row = reference.inactive.first
        #expect(row?.label == "Go to Space 6")
        // Not the Custom band's raw-Lua treatment.
        #expect(row?.monospaced == false)
        #expect(row?.label.contains("KiwiDesk.") == false)
        // It keeps the glyph its live twin would carry.
        #expect(row?.icon == "6.square")
        #expect(row?.combo.isEmpty == false)
        // A band that exists is a panel that is not empty.
        #expect(reference.isEmpty == false)
    }

    @Test("a live Space's shortcut stays in Controls")
    func liveSpacesAreUntouched() {
        reset()
        let reference = build(
            [binding("ctrl+alt+1", "KiwiDesk.focus_space(\"1\")")],
            spaces: [SpaceID("1")]
        )
        #expect(reference.inactive.isEmpty)
        let focus = reference.controls.first {
            $0.title == "Focus"
        }
        #expect(focus?.rows.count == 1)
    }

    @Test("every per-Space family reaches the band")
    func movingCommandsOrphanToo() {
        reset()
        let reference = build([
            binding("ctrl+alt+6", "KiwiDesk.focus_space(\"6\")"),
            binding(
                "ctrl+shift+6",
                "KiwiDesk.move_to_space(\"6\")"
            ),
        ])
        #expect(reference.custom.isEmpty)
        #expect(reference.inactive.count == 2)
        #expect(
            reference.inactive.allSatisfy {
                !$0.label.contains("KiwiDesk.")
            }
        )
    }

    @Test("a second combo for an orphan is never invisible")
    func twinStillSurfaces() {
        reset()
        // The band takes one row per orphaned command (the panel
        // renders a command once), so the twin must still land
        // somewhere — Custom, as it does for a live command's
        // twin, rather than vanishing.
        let reference = build([
            binding("ctrl+alt+6", "KiwiDesk.focus_space(\"6\")"),
            binding("alt+6", "KiwiDesk.focus_space(\"6\")"),
        ])
        #expect(reference.inactive.count == 1)
        #expect(reference.custom.count == 1)
    }

    /// The band above is data the view may simply not draw: the
    /// builder can fill `inactive` while `body` renders three
    /// bands, and every expectation in this suite stays green —
    /// the surfacing-branch hole Monitors paid for. So the
    /// drawing is needled at its use site, and so is the dim's
    /// caption, which is what stops a dimmed row from being a
    /// dead end.
    ///
    /// Stated limit: a needle proves the branch is WRITTEN, not
    /// that it draws the band correctly — that half needs the
    /// eye.
    @Test("the panel draws the band it was handed")
    func theViewDrawsTheBand() throws {
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Shortcuts/"
                    + "ShortcutsPanelView.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        for needle in [
            "inactive(reference.inactive)",
            // The dim, keyed past the rows' closing braces: the
            // Custom band draws the same `ForEach`, undimmed.
            "ShortcutRowView(row:$0)}}.opacity(0.6)",
            "Text(inactiveCaption)",
        ] {
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "ShortcutsPanelView no longer draws "
                        + "`\(needle)` — the Inactive band is "
                        + "gone from the screen with every "
                        + "builder expectation still green"
                )
            )
        }
    }

    @Test("the panel and Settings agree on what is inactive")
    func predicateIsSettings() {
        reset()
        let bindings = [
            binding("ctrl+alt+6", "KiwiDesk.focus_space(\"6\")"),
            binding("ctrl+alt+1", "KiwiDesk.focus_space(\"1\")"),
        ]
        let spaces = [SpaceID("1")]
        let settings = OrphanedShortcuts.commands(
            bindings: bindings,
            spaces: spaces,
            icons: [:]
        )
        let panel = build(bindings, spaces: spaces)
        #expect(
            panel.inactive.map(\.id) == settings.map(\.lua)
        )
    }
}
