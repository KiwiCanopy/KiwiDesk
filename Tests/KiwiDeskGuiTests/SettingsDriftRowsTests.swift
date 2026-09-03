import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The footer counts what the header claims (#1197): drift that
/// no draft leaf carries — a screen setup the active profile has
/// no set for, a built-in layout, a vanished match — is a diff
/// row with an anchor, under the header's own divergence
/// predicate. Locale pinned per body (#740); the model is the
/// test factory's, displays none.
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

    @Test("a built-in layout is a Profile row anchored at Profiles")
    func builtInLayoutIsAProfileRow() throws {
        pinEnglish()
        let model = makeTestModel()
        model.activeStandard = "Workflow"
        model.profileDirty = true
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first
        )
        #expect(row.key == .profiles(.profilesLoad))
        #expect(
            row.changeNote
                == L(
                    "profile_header.status.built_in",
                    "Built-in layout — save as a profile to "
                        + "make it yours."
                )
        )
        #expect(
            SettingsDiffJump.anchor(for: row)?.destination
                == .profiles
        )
    }

    @Test("no matching profile narrates the header's own sentence")
    func noMatchIsAProfileRow() throws {
        pinEnglish()
        let model = makeTestModel()
        model.profileDirty = true
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first
        )
        #expect(row.key == .profiles(.profilesLoad))
        #expect(
            row.changeNote
                == L(
                    "profile_header.status.no_match",
                    "No profile matches this monitor setup."
                )
        )
    }

    /// The predicate is the header's: no drift, no row — and a
    /// stored profile's draft carries none, the way the header
    /// hides divergence while one is being edited.
    @Test("a clean live state, or a stored draft, adds nothing")
    func cleanOrStoredAddsNothing() {
        pinEnglish()
        let clean = makeTestModel()
        clean.activeProfile = "Desk"
        #expect(SettingsDiffRowSource.rows(for: clean).isEmpty)
        let stored = driftedModel()
        stored.target = .storedProfile("Other")
        #expect(SettingsDiffRowSource.driftRows(for: stored).isEmpty)
    }

    /// The drift row's id keeps it apart from a config row on
    /// the same key, so both can sit in one list.
    @Test("a drift row is instanced")
    func driftRowIsInstanced() {
        pinEnglish()
        let row = SettingsDiffRowSource.driftRows(for: driftedModel())
        #expect(
            row.first?.id
                == SettingKey.monitors(.fingerprints).id + "#"
                + SettingsDiffRowSource.driftInstance
        )
    }
}
