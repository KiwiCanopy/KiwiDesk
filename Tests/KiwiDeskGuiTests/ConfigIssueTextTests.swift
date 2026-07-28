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
@Suite("Config issue text")
@MainActor
struct ConfigIssueTextTests {
    /// Every case, listed once. A new one fails to compile in
    /// `ConfigIssueText` before it reaches here.
    private let kinds: [ConfigIssue.Kind] = [
        .profileUnreadable,
        .luaVMUnavailable,
        .luaError("attempt to index a nil value"),
        .guiConfigUnreadable,
        .unknownCall(name: "KiwiDesk.focsu", suggestion: "focus"),
        .unknownCall(name: "KiwiDesk.nope", suggestion: nil),
    ]

    @Test("Every kind renders non-empty, distinct text")
    func everyKindRenders() {
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
