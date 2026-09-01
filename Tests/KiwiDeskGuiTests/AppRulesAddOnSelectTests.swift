import Foundation
import Testing

@testable import KiwiDesk

/// Picking an app IS the add (#1172) — there is no second step,
/// and the picked-but-not-added state it removes was also the one
/// state that drew no icon.
///
/// The whole change is a wiring change, so the whole guard is a
/// wiring guard: nothing headless can click a popover row. What
/// it holds is that the pick reaches a commit, that the free-text
/// path — the one exception the issue rules — keeps one, and that
/// the census key survived the button it used to label.
@Suite("App Rules add-on-select (#1172)")
struct AppRulesAddOnSelectTests {
    private func controls() throws -> String {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "AppRuleControls.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        // A read that came back empty would satisfy nothing
        // positive but would fail-open the moment a NEGATIVE
        // clause joined this suite (`guard-prover`, 2026-09-01).
        #expect(source.count > 200, "AppRuleControls.swift read empty")
        return source
    }

    /// The picker's own modifier chain — everything from the
    /// `AppPickerButton(` call to the end of the `else` branch.
    /// Read scoped rather than file-wide because both census
    /// clauses below were proved green with the label and the
    /// value moved onto the OTHER branch's controls, which is
    /// the state they exist to forbid.
    private func pickerChain() throws -> String {
        let source = try controls()
        let start = try #require(
            source.range(of: "AppPickerButton("),
            "the picker is gone from AppRuleControls.swift"
        )
        return String(source[start.lowerBound...])
    }

    private func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("picking an app commits it, with nothing in between")
    func pickCommits() throws {
        // Anchored on what the closure cannot LOSE — a commit
        // reached from the pick — rather than on its body
        // verbatim: the first cut pinned the closure's parameter
        // name, so renaming a local binding red the suite with a
        // regression message that was false (`guard-prover`,
        // 2026-09-01).
        let chain = squashed(try pickerChain())
        let pick = try #require(
            chain.range(of: squashed("onPick:")),
            "the picker states no onPick at all"
        )
        let escape = chain.range(of: squashed("escapeLabel:"))
        let body = String(
            chain[
                pick
                    .upperBound..<(escape?.lowerBound
                    ?? chain.endIndex)
            ]
        )
        #expect(
            body.contains("onCommit("),
            Comment(
                rawValue:
                    "the picker no longer commits what it picked "
                    + "— an app chosen from the list would sit in "
                    + "`name` with no rule added and no button "
                    + "left to add it, which is worse than the "
                    + "two-step this replaced (#1172)"
            )
        )
    }

    /// The exception, and the reason it is one: every keystroke
    /// of `com.apple.Safari` is a prefix of `com.apple.Safari`,
    /// so free text has no moment that means "this is the app".
    /// BOTH affordances are pinned — Return alone is invisible,
    /// and a button alone loses the keyboard.
    @Test("the typed path keeps a commit, on both channels")
    func customPathKeepsACommit() throws {
        let source = squashed(try controls())
        for (needle, why) in [
            (".onSubmit(commitCustom)", "Return commits"),
            (
                "Button(action: commitCustom)",
                "and a visible confirm commits too, so the only "
                    + "way to add a typed bundle id is not an "
                    + "unlabelled key press"
            ),
        ] {
            #expect(
                source.contains(squashed(needle)),
                Comment(
                    rawValue:
                        "the custom bundle-id field lost "
                        + "`\(needle)` — \(why), and without it a "
                        + "typed identifier is silently discarded "
                        + "when the field loses focus (#1172)"
                )
            )
        }
    }

    /// gui.md: a Settings-row change updates its census entry in
    /// the same change set. The key outlived the Button it used
    /// to label, so it has to be drawn by whatever replaced it —
    /// here the picker's own accessible name.
    @Test("the census key is still drawn by the add affordance")
    func censusKeyStillRendered() throws {
        // DERIVED from the census rather than restated beside
        // it: hand-typed on both sides, the two agree with each
        // other and with nothing else, and renaming the key reds
        // here instead of at the drawing site.
        guard case .key(let key) = AppRulesKey.appRulesAdd.text.label
        else {
            Issue.record("appRulesAdd no longer names a key")
            return
        }
        let chain = squashed(try pickerChain())
        #expect(
            chain.contains(
                squashed(".accessibilityLabel(L(\"\(key)\"")
            ),
            Comment(
                rawValue:
                    "`app_rules.add_rule` is claimed by the "
                    + "census but drawn nowhere — the Button that "
                    + "used to carry it is gone, so the picker "
                    + "that replaced it has to (#1172, #678)"
            )
        )
        // Naming a control REPLACES what it announced, so the
        // name owes the value back — here the Button's own text.
        #expect(
            chain.contains(".accessibilityValue("),
            Comment(
                rawValue:
                    "the picker is named but not valued — "
                    + "VoiceOver then says \"Add app rule\" and "
                    + "never which app is chosen (#812)"
            )
        )
    }
}
