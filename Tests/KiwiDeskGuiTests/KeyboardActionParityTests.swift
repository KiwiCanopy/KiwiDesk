import Foundation
import Testing

/// #678 Phase 4 pass 10, turn 20a rule 1: **the drag is the
/// shortcut and the menu is the mechanism** — so every mechanism
/// has to be reachable without the gesture that is merely its
/// shortcut.
///
/// A `.contextMenu` is right-click and nothing else. macOS has no
/// default key that opens a focused control's contextual menu, so
/// a mechanism that lives only there is pointer-only however many
/// keyboard-navigable things sit beside it. Every row menu
/// therefore routes through the ONE composition seam —
/// `rowActions(id:_:)` in `ContextShortcut.swift` — which takes
/// the builder ONCE and applies right-click, VoiceOver's named
/// actions and the focus-gated ⌃. chord itself (#845).
///
/// The guard is a channel BAN outside the seam plus structural
/// pins inside it, not a per-site builder comparison: with the
/// builder handed to the seam once, a crossed pairing or a
/// mirrored list cannot be EXPRESSED at a call site — the
/// pre-seam comparison guard's whole defect class (a two-menu
/// file with crossed pairings was green under it, prover
/// 2026-08-23). What remains expressible is a bare channel
/// beside the seam, which is what the ban reds on.
@Suite("Keyboard action parity")
struct KeyboardActionParityTests {
    /// The WHOLE GUI target, not just `Settings/`: a context
    /// menu added at target root (`ConfigIssuesWindow`,
    /// `StatusItemController+Menu`) is a pointer-only mechanism
    /// exactly like one inside the Settings tree, and a walk
    /// scoped to Settings reds on none of them (architect
    /// review, 2026-08-11).
    private var guiDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
    }

    private var settingsDir: URL {
        guiDir.appendingPathComponent("Settings")
    }

    /// The seam file, exempt from the channel ban because it is
    /// where the channels are legitimately spelled — once.
    private let seamFile = "ContextShortcut.swift"

    /// Bare channels a file may spell outside the seam, with the
    /// reason that IS each exemption. Empty on purpose: a
    /// genuine VoiceOver-only affordance (actions with no
    /// context menu) would be the first entry, argued here.
    private let bareChannelExempt: [String: String] = [:]

    @Test("every row menu routes through the one seam")
    func everyRowMenuRoutesThroughTheSeam() throws {
        let files = try SourceScan.swiftSources(under: guiDir)
        var seamCallFiles = 0
        for file in files {
            let name = file.lastPathComponent
            guard name != seamFile else { continue }
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            if source.contains("rowActions {")
                || source.contains("rowActions(")
            {
                seamCallFiles += 1
            }
            guard bareChannelExempt[name] == nil else { continue }
            // Both the trailing-closure and labeled-argument
            // spellings: `.contextMenu(menuItems:)` and
            // `.accessibilityActions(` are the same bare
            // channel wearing parentheses (re-review,
            // 2026-08-23). The singular
            // `.accessibilityAction(named:)` is a different
            // affordance and deliberately unbanned.
            for marker in [
                "contextMenu {", "contextMenu(",
                "accessibilityActions {",
                "accessibilityActions(",
                "contextShortcut {",
            ] {
                #expect(
                    !source.contains(marker),
                    Comment(
                        rawValue:
                            "\(name) spells `\(marker)` beside "
                            + "the seam — a bare channel is how "
                            + "a crossed pairing or a stale "
                            + "mirror ships; hand the builder "
                            + "to `rowActions(id:_:)` instead "
                            + "(#845), or argue an exemption in "
                            + "`bareChannelExempt`"
                    )
                )
            }
        }
        // A floor, not an exact count: a new row menu is
        // welcome. What the floor catches is the scan reading
        // zero files — a renamed directory or broken walker
        // passes the ban above by never reaching a file.
        #expect(
            seamCallFiles >= 4,
            Comment(
                rawValue:
                    "only \(seamCallFiles) file(s) call the "
                    + "rowActions seam — the walk found less "
                    + "than the tree is known to hold, so the "
                    + "ban above was not actually checked"
            )
        )
    }

    /// The seam's own composition, pinned structurally: the
    /// menu channels each hand off to the ONE `menu()` token,
    /// the chord is exactly `⌃.` matched in one place (prose in
    /// gui.md and the user guide states it, and this needle is
    /// what keeps the code from drifting under that prose —
    /// prover residue, 2026-08-23), and delivery is the ONE key
    /// monitor resolving the focused row and popping its REAL
    /// context menu with a synthetic right-click — per-row
    /// `.keyboardShortcut` bindings resolve first-in-hierarchy
    /// and cross-targeted destructive items (#845 review
    /// blocker), and a focus-gated hidden `Menu` never received
    /// the key on AppKit-backed focus at all (device QA
    /// 2026-08-23). Wiring pins, not behavior: whether the
    /// chord LANDS is the device checklist's, stated in the
    /// seam's doc.
    @Test("the seam composes one builder, one chord, one monitor")
    func seamComposesOneBuilderChordAndFocusGate() throws {
        let file =
            settingsDir
            .appendingPathComponent("Components/Common")
            .appendingPathComponent(seamFile)
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        for needle in [
            ".contextMenu { menu() }",
            ".accessibilityActions { menu() }",
            ".focusedValue(\\.rowActionFocus, catcher)",
            "charactersIgnoringModifiers == \".\"",
            "== .control",
            "addLocalMonitorForEvents(",
            "target.token?.openMenu?()",
            ".popover(",
        ] {
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "the seam lost `\(needle)` — its "
                        + "composition (one builder, the ⌃. "
                        + "chord, the focus gate) is what every "
                        + "call site now relies on (#845)"
                )
            )
        }
    }

    /// Turn 20a rule 4: **every shape change states a focus
    /// destination** — and the per-space override editor is the
    /// one sub-view in the tree that the shell cannot state one
    /// for, since the shell only sees `SettingsDestination`
    /// pushes and this branch is view state inside Spaces.
    ///
    /// Three wirings, three sites, and every one of them is a
    /// single line that reads as decoration and deletes without
    /// a compiler complaint. A `@FocusState` whose binding is
    /// never attached compiles, runs, and simply never moves
    /// focus — the failure is silent to everything except a
    /// person trying to use the keyboard, which is exactly the
    /// class of defect this pass exists to close.
    ///
    /// Each needle names the USE site rather than the
    /// declaration (the Monitors lesson: a bare property name
    /// matched its own `@FocusState` line and went green with
    /// every attachment deleted).
    @Test("the override sub-view states its focus destinations")
    func overrideEditorStatesItsFocusDestinations() throws {
        let wirings: [Wiring] = [
            Wiring(
                "SpacesSection+Overrides.swift",
                ".focused($overridesBackFocused)",
                "entering the sub-view focuses its back crumb"
            ),
            Wiring(
                "SpacesSection+Overrides.swift",
                "onAppear { overridesBackFocused = true }",
                "and something has to raise the flag"
            ),
            Wiring(
                "SpacesSection+ModePicker.swift",
                ".focused($returningRow, equals: space)",
                "the row's ALWAYS-drawn control is the return "
                    + "destination — the Overrides button that "
                    + "opens the editor is mode-gated, so binding "
                    + "there sent focus to the top of the list on "
                    + "a Simple-mode install"
            ),
            Wiring(
                "SpacesSection+Remove.swift",
                "returningRow = neighbour",
                "a deletion lands on the next row, not the top"
            ),
            // The four lists #816 brought up to the same shape.
            // Each needs BOTH halves — the destination a row
            // draws, and the assignment the deletion makes —
            // because either alone moves focus nowhere: an
            // unattached key is silent, and an attached key
            // nothing ever sets is decoration.
            // Both halves moved to `+RowActions.swift` with the
            // three controls when #789 split the file under the
            // §2.1 ceiling. The move is why this guard names a
            // FILE: the scan went red on the split rather than
            // going quiet, which is the whole point of keying a
            // needle on its use site.
            Wiring(
                "ProfilesSection+RowActions.swift",
                ".focused($returningRow, equals: summary.name)",
                "a profile row's always-drawn Load is its "
                    + "destination — the trash would put a "
                    + "destructive action under the next keypress "
                    + "and \"make default\" is conditional"
            ),
            Wiring(
                "ProfilesSection+RowActions.swift",
                "returningRow = neighbour",
                "and the deletion has to name it"
            ),
            Wiring(
                "ProfilesSection+Broken.swift",
                ".focused($returningRow, equals: name)",
                "a broken row has no Load, so Reveal is its "
                    + "always-drawn control"
            ),
            Wiring(
                "ProfilesSection+Broken.swift",
                "returningRow = neighbour",
                "and its deletion names a neighbour inside the "
                    + "broken list, never a healthy row under "
                    + "another heading"
            ),
            Wiring(
                "AppRuleRow.swift",
                ".focused($returningRow, equals: app)",
                "the rule sentence's space menu is the row's "
                    + "always-drawn control; the trash disables "
                    + "itself in override mode"
            ),
            Wiring(
                "AppRulesSection.swift",
                "returningRow = neighbour",
                "and the list that owns the deletion names it"
            ),
            Wiring(
                "LayerStripEditor.swift",
                ".focused($focusedChip, equals: name)",
                "every layer chip is a destination"
            ),
            Wiring(
                "LayerStripEditor.swift",
                // The whole expression, both arms: stopping at
                // the condition let the ternary be INVERTED —
                // focus named INTO a card that just retired —
                // and stay green (guard-prover, 2026-08-12).
                "focusedChip = stripSurvivesDeletion "
                    + "? KeyLayer.defaultName : nil",
                "and deleting the selected layer moves focus "
                    + "WITH the selection to the base chip — but "
                    + "only where the card survives the "
                    + "deletion, since in Simple mode losing the "
                    + "last custom layer retires the strip and "
                    + "naming a chip inside it lands at the top "
                    + "of the window"
            ),
            Wiring(
                "PaletteShelf.swift",
                ".focused($returningTile, equals: palette.name)",
                "a saved palette's tile is already a Button, so "
                    + "it is the destination"
            ),
            Wiring(
                "PaletteShelf+Actions.swift",
                "returningTile = neighbour",
                "and the delete names the next tile in reading "
                    + "order"
            ),
        ]
        let files = try SourceScan.swiftSources(under: settingsDir)
        for wiring in wirings {
            let file = try #require(
                files.first {
                    $0.lastPathComponent == wiring.file
                },
                "\(wiring.file) is gone"
            )
            // Squashed on BOTH sides: this suite matched raw
            // source until `swift format` wrapped one of these
            // ternaries across three lines and reddened a guard
            // whose subject had not changed — a reflow owes
            // nothing (tests.md), so the needle must survive one
            // (guard-prover, 2026-08-12).
            let source = squashed(
                SourceScan.stripComments(
                    try String(contentsOf: file, encoding: .utf8)
                )
            )
            #expect(
                source.contains(squashed(wiring.needle)),
                Comment(
                    rawValue:
                        "\(wiring.file) lost `\(wiring.needle)` "
                        + "— \(wiring.why), and an unattached "
                        + "@FocusState moves focus nowhere while "
                        + "compiling cleanly"
                )
            )
        }
    }

    /// Whitespace-free source, so a needle survives the
    /// formatter wrapping a call — or a ternary — across lines.
    private func squashed(_ source: String) -> String {
        source.split(whereSeparator: \.isWhitespace).joined()
    }

    /// One focus wiring: the file it lives in, the use site that
    /// proves it, and why that site matters.
    private struct Wiring {
        let file: String
        let needle: String
        let why: String

        init(_ file: String, _ needle: String, _ why: String) {
            self.file = file
            self.needle = needle
            self.why = why
        }
    }
}
