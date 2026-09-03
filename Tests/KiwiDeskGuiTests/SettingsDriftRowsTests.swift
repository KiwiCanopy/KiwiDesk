import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The footer counts what the header claims (#1197): drift that
/// no draft leaf carries — a screen setup the active profile has
/// no set for, a built-in layout, a vanished match — is ONE
/// verdict on the model (`profileDrift`), a diff row with an
/// anchor, and the header's own sentence. Locale pinned per body
/// (#740); the model is the test factory's, displays none. The
/// scan clause at the end reads three files once.
@MainActor
@Suite("Footer drift rows (#1197)")
struct SettingsDriftRowsTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func summary(
        _ name: String,
        count: Int
    ) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: true,
            matchesLive: false,
            matchesConnectedCount: count == 0,
            openingModes: [],
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    /// The reported state: header says "Unsaved monitor changes",
    /// footer said "Unsaved changes" and opened nothing.
    private func driftedModel(count: Int = 0) -> SettingsModel {
        let model = makeTestModel()
        model.activeProfile = "Desk"
        model.profileSummaries = [summary("Desk", count: count)]
        model.profileDirty = true
        return model
    }

    @Test("a screen setup the profile has no set for is a row")
    func screenDriftIsARow() throws {
        pinEnglish()
        let model = driftedModel()
        #expect(
            model.profileDrift == .screensUnsaved(profile: "Desk")
        )
        let rows = SettingsDiffRowSource.rows(for: model)
        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(row.key == .monitors(.fingerprints))
        #expect(row.changeNote?.contains("Desk") == true)
        // …and it jumps where the drift is visible.
        let anchor = try #require(SettingsDiffJump.anchor(for: row))
        #expect(anchor.destination == .monitors)
        #expect(anchor.anchor == "monitors.advanced.title")
    }

    /// A count mismatch is the drift Save cannot take up, and
    /// the row narrates the same hint that greys Save.
    @Test("a screen-count mismatch narrates the update hint")
    func countMismatchNarratesTheHint() throws {
        pinEnglish()
        let model = driftedModel(count: 2)
        let hint = try #require(model.updateHint)
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first
        )
        #expect(row.changeNote == hint)
    }

    /// A Profile row jumps to the Profiles ROOT, never a labelled
    /// control: no control renders the composing Standard, and
    /// the Saved profiles card's one anchored control is Load.
    @Test("a built-in layout is a Profile row at the Profiles root")
    func builtInLayoutIsAProfileRow() throws {
        pinEnglish()
        let model = makeTestModel()
        model.activeStandard = "Workflow"
        model.profileDirty = true
        #expect(model.profileDrift == .builtIn)
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first
        )
        #expect(row.key == .profiles(.profilesLoad))
        // The row's OWN sentence, naming what is missing and the
        // button that fixes it — never the header's status line.
        let note = try #require(row.changeNote)
        #expect(note.contains("built-in layout"))
        #expect(
            note.contains(
                L(
                    "footer.save_as_new_profile",
                    "Save as New Profile…"
                )
            )
        )
        let anchor = try #require(SettingsDiffJump.anchor(for: row))
        #expect(anchor.destination == .profiles)
        #expect(anchor.anchor == nil)
    }

    /// The deleted-match state: the header used to say "update
    /// the profile" here with no profile to update.
    @Test("no matching profile narrates the no-match sentence")
    func noMatchIsAProfileRow() throws {
        pinEnglish()
        let model = makeTestModel()
        model.profileDirty = true
        #expect(model.profileDrift == .noMatch)
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first
        )
        #expect(row.key == .profiles(.profilesLoad))
        let note = try #require(row.changeNote)
        #expect(note.contains("No saved profile"))
        #expect(
            note.contains(
                L(
                    "footer.save_as_new_profile",
                    "Save as New Profile…"
                )
            )
        )
        #expect(SettingsDiffJump.anchor(for: row)?.anchor == nil)
    }

    /// No drift, no verdict — and a stored profile's draft
    /// carries none, the way the header hides divergence while
    /// one is being edited; the pill then has no drift half.
    @Test("a clean live state, or a stored draft, adds nothing")
    func cleanOrStoredAddsNothing() {
        pinEnglish()
        let clean = makeTestModel()
        clean.activeProfile = "Desk"
        #expect(clean.profileDrift == nil)
        #expect(SettingsDiffRowSource.rows(for: clean).isEmpty)
        let stored = driftedModel()
        stored.target = .storedProfile("Other")
        #expect(!stored.liveDrift)
        #expect(SettingsDiffRowSource.driftRows(for: stored).isEmpty)
    }

    /// The drift row's id keeps it apart from a config row on
    /// the same key, so both can sit in one list — asserted as
    /// "differs from the bare key's", never by restating the
    /// row-id separator (guard-prover, 2026-09-03).
    @Test("a drift row is instanced")
    func driftRowIsInstanced() throws {
        pinEnglish()
        let row = try #require(
            SettingsDiffRowSource.driftRows(for: driftedModel()).first
        )
        #expect(row.key == .monitors(.fingerprints))
        #expect(row.id != row.key.id)
        #expect(row.id.hasSuffix(SettingsDiffRowSource.driftInstance))
    }

    /// The three surfaces read the ONE verdict rather than three
    /// copies of its predicate — the disagreement the issue names.
    /// Shape, not value: the needle is the seam's name at each
    /// use site, the surfaces' own ladders being theirs.
    @Test("footer, header and rows read one drift verdict")
    func surfacesShareTheVerdict() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        let wants: [String: String] = [
            "SettingsFooter.swift": "model.isDirty||model.liveDrift",
            "SettingsHeaderBar+Status.swift":
                "varshowDivergence:Bool{model.liveDrift}",
            "SettingsDiffRowSource+Drift.swift":
                "guardletdrift=model.profileDrift",
        ]
        for (file, needle) in wants {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(
                source.contains(needle),
                Comment(rawValue: "\(file) no longer reads the verdict")
            )
        }
    }
}
