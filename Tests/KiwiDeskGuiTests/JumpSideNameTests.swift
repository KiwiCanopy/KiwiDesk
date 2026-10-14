import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The key panel's sides by name and by key (#2245): each side's
/// shortcut row reads "Show" and the side's VoiceOver name, and
/// the scope switch prints each side's live chord as a hint.
/// `ShortcutsPanelNounTests` holds the pairing per catalog; this
/// suite holds that the views draw the keys it compares.
@MainActor
@Suite("The key panel's sides by name and by key")
struct JumpSideNameTests {
    @Test("each side's row is Show and the side's VoiceOver name")
    func rowNamesItsSide() {
        LocalizationManager.shared.select("en")
        let rows: [(JumpScope, NavCommand)] = [
            (.windows, KeybindingCatalog.jumpToWindow),
            (.layouts, KeybindingCatalog.showLayoutPicker),
        ]
        for (scope, row) in rows {
            #expect(row.lua == scope.lua)
            #expect(
                row.resolvedLabel
                    == "Show " + scope.panelName.lowercased()
            )
        }
    }

    @Test("the cycle help names each row where it means it")
    func cycleHelpNamesItsRows() throws {
        LocalizationManager.shared.select("en")
        let next = KeybindingCatalog.nextLayout.resolvedLabel
        let previous = KeybindingCatalog.previousLayout.resolvedLabel
        #expect(LayoutCycleWords.help.contains(next))
        #expect(!LayoutCycleWords.help.contains(previous))
        let cue = LayoutCycleWords.cueHelp
        let nextAt = try #require(cue.range(of: next))
        let previousAt = try #require(cue.range(of: previous))
        #expect(nextAt.lowerBound < previousAt.lowerBound)
    }

    @Test("each side's chord is read for its own shortcut's Lua")
    func chordFollowsTheBinding() {
        let bound = [
            KeybindingCatalog.jumpToWindow.lua: "⌃⌥W",
            KeybindingCatalog.showLayoutPicker.lua: "⌃⌥P",
        ]
        let chords = JumpPanelController.chords { bound[$0] }
        #expect(chords[.windows] == "⌃⌥W")
        #expect(chords[.layouts] == "⌃⌥P")
        // A side whose shortcut is unbound prints no chord.
        let unbound = JumpPanelController.chords { _ in nil }
        #expect(unbound.isEmpty)
    }

    @Test("the panel reads the live bindings and the switch draws them")
    func chordsAreWired() throws {
        let controller = try Self.source("JumpPanelController.swift")
        #expect(
            controller.occurrences(of: "model.chords = liveChords()") == 1
        )
        // A layer switch re-reads them on whatever side shows.
        let reload = try Self.source("JumpPanelController+Shortcuts.swift")
        #expect(reload.occurrences(of: "model.chords = liveChords()") == 1)
        #expect(
            controller.occurrences(
                of: "ShortcutsOpenBinding.comboGlyphs(core: core, lua:"
            ) == 1
        )
        let chrome = try Self.source("JumpPanelChrome.swift")
        #expect(chrome.occurrences(of: "hints: model.chords") == 1)
        // VoiceOver hears the chord in the panel's own frame, as
        // the layout tiles speak theirs.
        #expect(
            chrome.occurrences(
                of: "spokenHint: LayoutPickText.chordHint"
            ) == 1
        )
    }

    @Test("the panel is named for the side it shows")
    func panelIsNamed() throws {
        let view = try Self.source("JumpPanelView.swift")
        #expect(
            view.occurrences(
                of: ".accessibilityLabel(model.scope.panelName)"
            ) == 1
        )
    }

    /// The product name is the OUTER container, around the side's
    /// own, so a side announces "KiwiHub, window switcher" (#2265).
    @Test("KiwiHub's name is spoken around the side's")
    func kiwiHubWrapsTheSide() throws {
        LocalizationManager.shared.select("en")
        #expect(JumpScope.panelName == "KiwiHub")
        let view = try Self.source("JumpPanelView.swift")
            .split(whereSeparator: \.isWhitespace).joined()
        let body = try #require(
            SourceScan.declarationBody(after: "varbody:someView", in: view)
        )
        #expect(
            body.contains(
                "VStack(spacing:0){side}"
                    + ".accessibilityElement(children:.contain)"
                    + ".accessibilityLabel(JumpScope.panelName)"
            )
        )
        let side = try #require(
            SourceScan.declarationBody(
                after: "privatevarside:someView",
                in: view
            )
        )
        #expect(side.contains(".accessibilityLabel(model.scope.panelName)"))
    }

    @Test("a chord is the segment's hint, never its name")
    func chordIsAHint() throws {
        let picker = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/"
                            + "Common/SegmentedPicker.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(
            picker.occurrences(
                of: ".accessibilityHint(hints[option.value].map(spokenHint)"
            ) == 1
        )
        let body = try #require(
            picker.range(of: "private func hintText(")
        )
        let rest = picker[body.lowerBound...]
        let end = try #require(rest.range(of: "\n    }\n"))
        let hintBody = rest[..<end.upperBound]
        #expect(hintBody.contains(".accessibilityHidden(true)"))
        // The inks the contrast suite measures, drawn here — the
        // pairing reads the token and cannot see the site.
        #expect(hintBody.contains("SettingsTheme.accentInkSecondary"))
        #expect(hintBody.contains(": SettingsTheme.ink2"))
    }

    private static func source(_ name: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent("Sources/KiwiDesk/Jump/\(name)"),
                encoding: .utf8
            )
        )
    }
}
