import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every `ConfigIssue.Kind` must render to real localized text at
/// the GUI boundary (#96/#601).
///
/// This is the half a source scan cannot reach. The boundary
/// guard (`CoreLocalizationBoundaryTests`) proves Core is not
/// *calling* `L()`; nothing about that stops a new `Kind` case
/// from being added and rendered as a hardcoded English literal
/// here — which is exactly how four of these messages shipped
/// untranslatable in the first place. Switching over the enum
/// makes the compiler demand a case, and these assertions demand
/// that the case produce a catalog-visible string.
/// `.serialized` and locale-pinned for the reason
/// `SystemShortcutNamesTests` and `StandardLayoutDisplayTests`
/// already carry: `LocalizationManager` is a process-wide
/// singleton and other suites `select()` into it concurrently, so
/// an unpinned assertion here is really about whichever catalog
/// won the race — `tests.md`'s "pin the display, never inherit
/// it", applied to the locale.
@Suite("Config issue text", .serialized)
@MainActor
struct ConfigIssueTextTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// Every case, listed once. A hand-listed mirror, and
    /// therefore one more place to forget
    /// (`.claude/rules/parity-tests.md`): the compiler forces a
    /// new case into `ConfigIssueText`'s exhaustive switch, but
    /// nothing forces it into this array, so a new `Kind` would
    /// skip the assertions below. Associated values rule out
    /// `CaseIterable`; the count check at the end is the
    /// backstop.
    ///
    /// `profileBroken` appears once per `ProfileBrokenCause`,
    /// which is also this suite's coverage of `ProfileBrokenText`:
    /// that renderer has no suite of its own because every one of
    /// its sentences reaches the user through this switch, and the
    /// distinctness assertion below is what pins that the three
    /// causes do not collapse to one string (#678 Phase 4 pass 9).
    /// The row's OTHER reader — App ▸ Profiles — calls the same
    /// function, so a collapse here is a collapse there.
    private var kinds: [ConfigIssue.Kind] {
        // DERIVED from `allCases`, not restated: a fourth cause
        // then reaches the distinctness assertion below instead
        // of being forced into `ProfileBrokenText`'s switch by
        // the compiler and skipping every test here (architect
        // review, 2026-08-11).
        ProfileBrokenCause.allCases.map { .profileBroken($0) } + [
            .luaVMUnavailable,
            .luaError("attempt to index a nil value"),
            .guiConfigUnreadable,
            .unknownCall(
                name: "KiwiDesk.focsu",
                suggestion: "focus"
            ),
            .unknownCall(name: "KiwiDesk.nope", suggestion: nil),
        ]
    }

    @Test("Every kind renders non-empty, distinct text")
    func everyKindRenders() {
        pinEnglish()
        defer { reset() }
        // Five cases; the fixture count is three causes plus the
        // five hand-listed entries (`unknownCall` twice). The
        // cause half derives, so only the hand-listed half is
        // pinned — bump the 5 deliberately when a `Kind` is
        // added, which is the reminder the compiler cannot give.
        #expect(kinds.count == ProfileBrokenCause.allCases.count + 5)
        var seen: Set<String> = []
        for kind in kinds {
            let text = ConfigIssueText.message(for: kind)
            #expect(!text.isEmpty, "\(kind) rendered empty")
            // Distinctness matters: a copy-paste that reused one
            // key for two cases would show the wrong sentence and
            // trip the localization collapse guard downstream.
            #expect(
                seen.insert(text).inserted,
                "\(kind) duplicates another kind's text"
            )
        }
    }

    @Test("The interpreter's own message survives verbatim")
    func luaErrorKeepsItsDetail() {
        pinEnglish()
        defer { reset() }
        // The payload is machine output the user will search for,
        // so only the frame around it is localized — the same
        // rule that keeps CLI/IPC errors English.
        let detail = "init.lua:3: attempt to call a nil value"
        let text = ConfigIssueText.message(
            for: .luaError(detail)
        )
        #expect(text.contains(detail))
    }

    @Test("A suggestion changes the sentence, not just the data")
    func suggestionSelectsItsOwnKey() {
        pinEnglish()
        defer { reset() }
        // Two keys, because a translator cannot append "did you
        // mean X?" to a sentence that did not leave room for it.
        let without = ConfigIssueText.message(
            for: .unknownCall(name: "a.b", suggestion: nil)
        )
        let with = ConfigIssueText.message(
            for: .unknownCall(name: "a.b", suggestion: "a.c")
        )
        #expect(without != with)
        #expect(with.contains("a.c"))
        #expect(!without.contains("a.c"))
    }
}
