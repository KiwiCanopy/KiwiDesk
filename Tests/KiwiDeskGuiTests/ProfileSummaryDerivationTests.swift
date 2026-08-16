import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The two live-hardware flags on `ProfileSummary`, asserted
/// against the DERIVATION in `refreshProfiles` rather than
/// against hand-built fixtures (#789).
///
/// Why this suite exists, stated because it is the gap it fills:
/// `ProfilesFamilyRowsTests` proves the sort HONOURS
/// `matchesConnectedCount`, and `ProfilesCensusRenderTests`
/// proves the expansion reads the ordered list — but both
/// *supply* the flag as fixture data. Nothing observed the
/// expression that computes it, so hardwiring it to `false` (the
/// flag never fires and #789's defect returns whole) or shifting
/// it by one (every profile mis-ranked) left all 3350 tests
/// green, twice (guard-prover and a code review found it
/// independently, 2026-08-16). Reverting #789 reds the sort
/// suite; the sub-diff mutation that actually breaks the
/// user-visible order did not red anything.
///
/// `matchesLive` is asserted here too. It was equally unpinned
/// before this suite — an inherited gap rather than one #789
/// created — and the two are derived one line apart from the
/// same read, so a suite that covered only the new one would
/// leave the older half of the same fact unwatched.
///
/// The display list is PINNED (`displaysChanged`), never
/// inherited from the host: a suite that let the real `NSScreen`
/// answer would assert whatever the developer had plugged in.
@MainActor
@Suite("Profile summary derivations (#789)", .serialized)
struct ProfileSummaryDerivationTests {
    private func display(
        _ id: UInt32,
        _ name: String,
        width: CGFloat,
        x: CGFloat = 0
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: name,
            frame: CGRect(x: x, y: 0, width: width, height: 1080)
        )
    }

    /// Two connected screens, neither of them any profile's.
    private func makeModel(displays: [Display]) -> SettingsModel {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        core.state.apply(.displaysChanged(displays))
        return makeTestModel(core: core)
    }

    /// `write`, not `save`: saving ADOPTS the profile (#18), and
    /// these need to be stored-but-inactive.
    private func store(
        _ model: SettingsModel,
        named name: String,
        monitors: [String]
    ) {
        try? model.core.profiles.write(
            Profile(
                name: name,
                monitorSets: [MonitorSet(monitors: monitors)],
                spaces: [SpaceID("1")],
                spaceModes: [SpaceID("1"): .bsp],
                settings: TilingSettings()
            )
        )
    }

    private func summary(
        _ model: SettingsModel,
        _ name: String
    ) -> ProfileSummary? {
        model.profileSummaries.first { $0.name == name }
    }

    /// The whole point of the key: a profile saved for as many
    /// screens as are connected, but for DIFFERENT monitors, is
    /// count-matching and not live-matching. Hardwiring the
    /// derivation to `false` reds here; nothing else in the tree
    /// notices.
    @Test("a same-count profile for other monitors matches count")
    func sameCountOtherMonitorsMatchesCountOnly() {
        let model = makeModel(displays: [
            display(1, "Main", width: 1920),
            display(2, "Second", width: 1920, x: 1920),
        ])
        store(
            model,
            named: "Away",
            monitors: ["Café:1920x1080", "Hotel:1920x1080"]
        )
        model.reload()

        let away = summary(model, "Away")
        #expect(away?.matchesConnectedCount == true)
        #expect(away?.matchesLive == false)
    }

    /// And the other side, which is what an off-by-one
    /// derivation would break: fewer screens than are connected
    /// is not a count match.
    @Test("a fewer-screen profile does not match the count")
    func fewerScreensDoesNotMatch() {
        let model = makeModel(displays: [
            display(1, "Main", width: 1920),
            display(2, "Second", width: 1920, x: 1920),
        ])
        store(model, named: "Solo", monitors: ["Café:1920x1080"])
        model.reload()

        let solo = summary(model, "Solo")
        #expect(solo?.matchesConnectedCount == false)
        #expect(solo?.matchesLive == false)
    }

    /// More screens than are connected is not a match either —
    /// the pair with the test above is what pins the derivation
    /// to equality rather than to a comparison in either
    /// direction.
    @Test("a more-screen profile does not match the count")
    func moreScreensDoesNotMatch() {
        let model = makeModel(displays: [
            display(1, "Main", width: 1920)
        ])
        store(
            model,
            named: "Desk",
            monitors: ["Café:1920x1080", "Hotel:1920x1080"]
        )
        model.reload()

        let desk = summary(model, "Desk")
        #expect(desk?.matchesConnectedCount == false)
    }

    /// The fingerprint half, one line up in the same derivation:
    /// a profile saved for exactly these monitors matches live,
    /// and matches the count too — which is why the sort's first
    /// key dominates the second rather than disagreeing with it.
    @Test("a profile for these very monitors matches both")
    func exactMonitorsMatchBoth() {
        let model = makeModel(displays: [
            display(1, "Main", width: 1920),
            display(2, "Second", width: 1920, x: 1920),
        ])
        store(
            model,
            named: "Here",
            monitors: ["Main:1920x1080", "Second:1920x1080"]
        )
        model.reload()

        let here = summary(model, "Here")
        #expect(here?.matchesLive == true)
        #expect(here?.matchesConnectedCount == true)
    }

    /// And the derivation feeds the ORDER the screen draws, not
    /// just the summary — the join, without which both halves
    /// could be right while the list ignored them.
    @Test("the derived flags order the live list")
    func derivedFlagsOrderTheList() {
        let model = makeModel(displays: [
            display(1, "Main", width: 1920),
            display(2, "Second", width: 1920, x: 1920),
        ])
        store(model, named: "Solo", monitors: ["Café:1920x1080"])
        store(
            model,
            named: "Away",
            monitors: ["Café:1920x1080", "Hotel:1920x1080"]
        )
        model.reload()

        let ordered = ProfilesFamilyRows.orderedProfiles(
            model.profileSummaries
        )
        // "Away" is count-matching, "Solo" is not — so Away
        // leads despite sorting later by both name and count.
        #expect(ordered.map(\.name) == ["Away", "Solo"])
    }
}
