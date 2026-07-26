import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The other half of the #96 split: Core names a reserved macOS
/// shortcut as a `SystemShortcut` case and the GUI resolves the
/// display string, because `L()` is `@MainActor` and Core's
/// conflict detection is actor-free (§2.6).
///
/// The case list is mirrored **twice**, and only one of the two
/// mirrors is compiler-guarded:
///
/// - `localizedName` switches exhaustively, so a new case cannot
///   ship without a string. Nothing to add.
/// - `SystemShortcuts.map` is a hand-written combo list, and a
///   case missing from it compiles fine — the shortcut is simply
///   never detected. That is the silent "add a field, forget one
///   site" shape `.claude/rules/parity-tests.md` requires a test
///   for, and `CaseIterable` makes it a reflection-style guard
///   rather than a second hand-listed one.
///
/// What neither reaches is two cases resolving to the SAME
/// string, which is what a copy-pasted `L(…)` line produces.
/// `.serialized` because `LocalizationManager` is a process-wide
/// singleton.
@Suite("System shortcut names (#96)", .serialized)
@MainActor
struct SystemShortcutNamesTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The mirror the compiler cannot see: a case with no combo
    /// in `SystemShortcuts.map` ships as dead code — it has a
    /// name, and nothing ever resolves to it, so the shortcut it
    /// describes is never flagged as a conflict.
    @Test("every case is reachable from a parsed combo")
    func everyCaseHasACombo() {
        let mapped = SystemShortcuts.map.values
        for shortcut in SystemShortcut.allCases {
            let message =
                "\(shortcut) has no entry in SystemShortcuts.map "
                + "— it can never be detected, so the conflict it "
                + "names is silently never reported"
            #expect(
                mapped.contains(shortcut),
                Comment(rawValue: message)
            )
        }
    }

    @Test("every case resolves to a distinct, non-empty name")
    func namesAreDistinctAndPresent() {
        pinEnglish()
        defer { reset() }
        var seen: [String: SystemShortcut] = [:]
        for shortcut in SystemShortcut.allCases {
            let name = shortcut.localizedName
            #expect(!name.isEmpty)
            if let clash = seen[name] {
                let message =
                    "\(shortcut) and \(clash) both resolve to "
                    + "\"\(name)\" — one L(…) line was copied "
                    + "without editing its key"
                Issue.record(Comment(rawValue: message))
            }
            seen[name] = shortcut
        }
        #expect(seen.count == SystemShortcut.allCases.count)
    }

    /// The whole point of the split: the tooltip a row shows is
    /// built at the GUI boundary from the case, so it can be
    /// translated. Composed rather than compared to a literal, so
    /// this stays true once the German strings land (#95).
    @Test("a system-shortcut tooltip renders the resolved name")
    func tooltipRendersResolvedName() {
        pinEnglish()
        defer { reset() }
        // ⌘W is Close Window, and nothing else in this one-row
        // set can collide with it.
        let bindings = [KeyBinding(combo: "command+w", lua: "a")]
        guard
            let tooltip = ConflictText.tooltip(
                for: bindings[0],
                in: bindings
            )
        else {
            Issue.record("⌘W did not report a system conflict")
            return
        }
        #expect(
            tooltip.contains(
                SystemShortcut.closeWindow.localizedName
            )
        )
        guard let combo = KeyCombo.parse("command+w") else {
            Issue.record("⌘W did not parse")
            return
        }
        #expect(SystemShortcuts.map[combo] == .closeWindow)
    }

    @Test("an unrecognized combo tooltips without a name")
    func unrecognizedTooltip() {
        pinEnglish()
        defer { reset() }
        let bindings = [KeyBinding(combo: "not+a+key", lua: "a")]
        #expect(
            ConflictText.tooltip(for: bindings[0], in: bindings)
                == "Not a recognized shortcut."
        )
    }
}
