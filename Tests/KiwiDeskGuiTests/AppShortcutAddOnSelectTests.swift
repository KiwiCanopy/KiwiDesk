import Foundation
import Testing

@testable import KiwiDesk

/// Picking an app IS the add here too (#1235) — the sibling of
/// `AppRulesAddOnSelectTests`, one surface later.
///
/// The two rows used the same picker with different contracts:
/// app rules created on pick, app shortcuts only remembered, and
/// asked for a second press that could only ever say yes to a
/// decision already made. This is a wiring change, so this is a
/// wiring guard — nothing headless clicks a popover row.
///
/// It carries a **fourth** clause the app-rules suite does not
/// need, and that clause is the whole reason this change was not
/// a deletion: the removed button was the ONE thing refusing an
/// app the "Other…" panel can still reach, so its branch has to
/// SAY so rather than return bare.
@Suite("App shortcut add-on-select (#1235)")
struct AppShortcutAddOnSelectTests {
    private static let directory =
        "Sources/KiwiDesk/Settings/Components/Keybindings/"

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.directory)
            .appendingPathComponent(file)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // A read that came back empty satisfies every NEGATIVE
        // clause below for free.
        #expect(
            text.count > 200,
            Comment(rawValue: "\(file) read empty")
        )
        return text
    }

    private func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    /// `declaration`'s own balanced body, via the shared scoper.
    private func declarationBody(
        _ declaration: String,
        in source: String
    ) throws -> String {
        try #require(
            SourceScan.declarationBody(
                of: declaration,
                in: source
            ),
            Comment(rawValue: "no `\(declaration)` to scan")
        )
    }

    /// The picker's OWN modifier chain — from the
    /// `AppPickerButton(` call to the end of its arguments plus
    /// the modifiers hung on it, stopping before the caption
    /// beside it.
    ///
    /// The first cut of this ran to end-of-file and called
    /// itself scoped; the picker is the first thing in the file,
    /// so "scoped" was "everything" and both census clauses
    /// below would have passed with the label moved onto the
    /// enclosing `VStack` — which is the #812 defect they exist
    /// to forbid, since a name on the container swallows the
    /// control's own (code review 2026-09-06).
    private func pickerChain() throws -> String {
        let text = squashed(
            try source("KeybindingAppGroup+AddRow.swift")
        )
        let start = try #require(
            text.range(of: "AppPickerButton("),
            Comment(rawValue: "the add row has no picker at all")
        )
        let rest = text[start.upperBound...]
        // The caption is the picker's sibling, so the chain ends
        // where the `if let notice` branch begins.
        let end = rest.range(of: "ifletnotice")
        return String(rest[..<(end?.lowerBound ?? rest.endIndex)])
    }

    @Test("both pick routes reach the add, with nothing between")
    func bothRoutesCommit() throws {
        let chain = try pickerChain()
        // The LIST route and the "Other…" panel route both land
        // on the same call. Anchored on reaching `add(`, not on
        // a closure body verbatim — the app-rules suite red on a
        // renamed local once already.
        #expect(
            chain.contains("onPick:{add("),
            Comment(
                rawValue:
                    "picking from the list no longer adds — the "
                    + "app would sit chosen with no row created "
                    + "and no button left to create it, which is "
                    + "worse than the two-step this replaced"
            )
        )
        #expect(
            chain.contains("pickBundleFromPanel(){add("),
            Comment(
                rawValue:
                    "the \u{201C}Other\u{2026}\u{201D} panel no "
                    + "longer reaches the add, so a bundle "
                    + "chosen there is silently discarded"
            )
        )
    }

    /// The confirm step is gone, and stays gone.
    @Test("no second press stands between the pick and the row")
    func noConfirmStep() throws {
        let body = try declarationBody(
            "varaddRow:someView",
            in: squashed(
                try source("KeybindingAppGroup+AddRow.swift")
            )
        )
        // A STANDALONE `Button`, so `AppPickerButton` is not a
        // match — and every spelling of one, since `Button{`
        // alone let `Button(action:)`, `Button("…")` and
        // `Button(L(…))` reinstate the step this bans.
        let letters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "_")
        )
        var found = false
        var index = body.startIndex
        while let hit = body.range(of: "Button", range: index..<body.endIndex)
        {
            let before =
                hit.lowerBound == body.startIndex
                ? nil : body[body.index(before: hit.lowerBound)]
            if before == nil
                || !(before!.unicodeScalars.allSatisfy {
                    letters.contains($0)
                })
            {
                found = true
                break
            }
            index = hit.upperBound
        }
        #expect(
            !found,
            Comment(
                rawValue:
                    "the add row grew a button again — a confirm "
                    + "after a pick carries no information, and "
                    + "the app rules row beside it has none"
            )
        )
    }

    /// **The clause this surface earns and app rules does not.**
    ///
    /// The picker list omits fully-bound apps, but
    /// `pickBundleFromPanel()` bypasses that list, so the
    /// "Other…" route can still name one. The greyed button used
    /// to stand there; with it gone the branch must record the
    /// refusal, or the pick does nothing and says nothing —
    /// strictly worse than the friction removed.
    @Test("a refused pick records instead of returning bare")
    func refusalIsRecordedNotDropped() throws {
        // Anchored on the BRANCH reaching a refusal, not on its
        // spelling: the first cut pinned the local parameter
        // name in two files, so renaming it would have redded
        // the suite with a message that was false — the lesson
        // `AppRulesAddOnSelectTests` already records from its
        // own guard-prover round.
        for (file, function) in [
            ("KeybindingAppGroup+AddRow.swift", "funcadd("),
            ("KeybindingAppGroup+Row.swift", "privatefuncassign("),
        ] {
            let body = try declarationBody(
                function,
                in: squashed(try source(file))
            )
            let guardClause = try #require(
                body.range(of: "else{").map {
                    String(body[$0.upperBound...].prefix(60))
                },
                Comment(
                    rawValue:
                        "\(file)'s \(function) no longer guards "
                        + "the no-behavior case at all"
                )
            )
            #expect(
                guardClause.contains("refuse("),
                Comment(
                    rawValue:
                        "\(file)'s no-behavior branch returns "
                        + "without recording a refusal "
                        + "(`\(guardClause.prefix(40))`) — an "
                        + "\u{201C}Other\u{2026}\u{201D} pick of "
                        + "a fully-bound app would create nothing "
                        + "and say nothing"
                )
            )
            // Both routes RETIRE it too, or the channel this
            // change calls one channel is retired from one of
            // them and a caption narrates a pick two actions old.
            #expect(
                body.contains("clearRefusal()"),
                Comment(
                    rawValue:
                        "\(file)'s successful path no longer "
                        + "clears the refusal, so its caption "
                        + "stands after a later pick succeeds"
                )
            )
        }
        // DERIVED, not stored: the sentence re-asks the live
        // question, so freeing a behavior clears it with nothing
        // having to notice.
        let notice = try declarationBody(
            "funcallBoundNotice(aboutapp:",
            in: squashed(try source("KeybindingAppGroup+AddRow.swift"))
        )
        #expect(
            notice.contains(
                "firstAvailableBehavior(for:app.bundleID)==nil"
            ),
            Comment(
                rawValue:
                    "the refusal notice no longer re-derives "
                    + "from live state (`\(notice.prefix(60))`) — "
                    + "a stored message stands after the user "
                    + "frees a behavior"
            )
        )
    }

    /// The caption belongs to the picker that refused.
    ///
    /// Drawn only at the add row, a refusal raised from row 2 of
    /// twenty painted below row 20 — silent for a sighted user on
    /// any list long enough to scroll (code review 2026-09-06).
    /// Keyed rather than per-row-unconditional, so it stays ONE
    /// sentence instead of gui.md's caption under every child.
    @Test("the refusal draws at the picker that raised it")
    func refusalDrawsAtItsOwnPicker() throws {
        let row = squashed(try source("KeybindingAppGroup+Row.swift"))
        #expect(
            row.contains("allBoundNotice(for:binding.wrappedValue.id)"),
            Comment(
                rawValue:
                    "a row no longer asks for ITS refusal — the "
                    + "sentence would print at the bottom of the "
                    + "group, away from the pick that raised it"
            )
        )
        #expect(
            try declarationBody("funcrow(", in: row)
                .contains("rowNotice(binding)"),
            Comment(
                rawValue:
                    "the row no longer draws its notice at all"
            )
        )
    }

    /// gui.md: a Settings-row change updates its census entry in
    /// the same change set, and naming a control REPLACES what it
    /// announced. The key outlived the Button it labelled.
    @Test("the add key is drawn by whatever replaced the button")
    func addKeyStillRendered() throws {
        let chain = try pickerChain()
        #expect(
            chain.contains(
                squashed(".accessibilityLabel(L(\"shortcuts.add_application\"")
            ),
            Comment(
                rawValue:
                    "`shortcuts.add_application` is drawn "
                    + "nowhere — the Button that carried it is "
                    + "gone, so the picker that replaced it has "
                    + "to, or the last row of the section never "
                    + "says it creates a shortcut"
            )
        )
        #expect(
            chain.contains(".accessibilityValue("),
            Comment(
                rawValue:
                    "the picker is named but not valued — "
                    + "VoiceOver then says \"Add application\" "
                    + "and never what the control shows (#812)"
            )
        )
    }
}
