import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The other half of the #96 split: Core names a reserved macOS
/// shortcut as a `SystemShortcut` case and the GUI resolves the
/// display string, because `L()` is `@MainActor` and Core's
/// conflict detection is actor-free (§2.6).
///
/// The **compiler** guards the mirror — `localizedName` switches
/// exhaustively, so a new case cannot ship without a string.
/// What it cannot see is two cases resolving to the SAME string,
/// which is what a copy-pasted `L(…)` line produces, so that is
/// what this suite adds. `.serialized` because
/// `LocalizationManager` is a process-wide singleton.
@Suite("System shortcut names (#96)", .serialized)
@MainActor
struct SystemShortcutNamesTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
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
