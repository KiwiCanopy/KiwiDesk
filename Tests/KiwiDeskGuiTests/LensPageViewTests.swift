import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The lens page's decisions a view reads (#2103 rulings 29, 38,
/// 51, 52): which chip is selected, when "Windows titled…" shows,
/// how Clear after and Applies to read.
@Suite("Lens page views (#2103)")
@MainActor
struct LensPageViewTests {
    @Test("the chip follows the lens, ignoring case, else Focused window")
    func selection() {
        var nav = SettingsNavigation()
        let lenses = [VisionLens(name: "Writing")]
        #expect(nav.kiwiVisionLensSelection(in: lenses) == nil)
        nav.kiwiVisionLens = "writing"
        #expect(nav.kiwiVisionLensSelection(in: lenses) == "Writing")
        nav.kiwiVisionLens = "Gone"
        #expect(nav.kiwiVisionLensSelection(in: lenses) == nil)
    }

    @Test("Windows titled… shows in Power User, or once a member is titled")
    func titlesOffer() {
        var lens = VisionLens(name: "Writing")
        lens.apps = ["test.kiwi.notes"]
        #expect(!KiwiVisionLensAppsCard.offersTitles(lens, mode: .simple))
        #expect(KiwiVisionLensAppsCard.offersTitles(lens, mode: .powerUser))
        lens.titles = ["test.kiwi.notes": []]
        #expect(KiwiVisionLensAppsCard.offersTitles(lens, mode: .simple))
    }

    @Test("Clear after reads Off at 0, else seconds")
    func delayReadout() {
        LocalizationManager.shared.select("en")
        #expect(KiwiVisionLensWords.delay(0) == "Off")
        #expect(KiwiVisionLensWords.delay(2) == "2 s")
        #expect(KiwiVisionLensWords.delay(2.5) == "2.5 s")
    }

    @Test("Applies to names the saved profiles a lens reaches")
    func reachLabel() {
        LocalizationManager.shared.select("en")
        let all = ["Home", "Office", "Studio"]
        #expect(KiwiVisionLensWords.reachLabel(all, of: all) == "All profiles")
        #expect(
            KiwiVisionLensWords.reachLabel([], of: all)
                == "Built-in layouts only"
        )
        #expect(
            KiwiVisionLensWords.reachLabel(["Home"], of: all) == "Home only"
        )
        #expect(
            KiwiVisionLensWords.reachLabel(["Home", "Office"], of: all)
                == "Home, Office"
        )
    }
}
