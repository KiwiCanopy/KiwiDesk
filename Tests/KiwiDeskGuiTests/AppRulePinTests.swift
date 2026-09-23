import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Which Space a new "Open in a Space" rule takes (#1022, #1608),
/// and the pointer the Space list draws when there is none.
///
/// Since #1608 a row in that list always holds a Space, so what
/// was a three-cased "must this row keep its pin" verdict is gone
/// with the one-row form it answered for; what remains is the
/// value a pick writes. `AppRuleListsWiringTests` holds the lists.
@Suite("App rule pin (#1022)")
struct AppRulePinTests {
    private func config(
        spaces: [String],
        fallback: String? = nil
    ) -> GuiConfig {
        var config = GuiConfig()
        config.spaces = spaces.map { SpaceID($0) }
        config.fallbackSpace = fallback.map { SpaceID($0) }
        return config
    }

    // MARK: - What an engaged pin selects

    /// `fallbackSpace` is the rehome target #68 already
    /// designates — "where windows land when a profile switch
    /// drops their space" — so the pin reuses it rather than
    /// coining a second notion of "the default Space".
    @Test("an engaged pin takes the designated fallback")
    func fallbackWinsOverListOrder() {
        let config = config(
            spaces: ["1", "work", "media"],
            fallback: "media"
        )
        #expect(
            AppRulePin.engagedSpace(config) == SpaceID("media"),
            Comment(
                rawValue:
                    "never an arbitrary list position while a "
                    + "fallback is designated"
            )
        )
    }

    @Test("with no fallback it takes the first Space")
    func firstSpaceIsTheFallbacksFallback() {
        let config = config(spaces: ["1", "work"])
        #expect(AppRulePin.engagedSpace(config) == SpaceID("1"))
    }

    /// A `fallbackSpace` naming a space this config no longer
    /// lists would otherwise author a pin to a space the menu
    /// cannot show — a row whose value is invisible in its own
    /// dropdown.
    @Test("a stale fallback falls through to the first Space")
    func staleFallbackIsIgnored() {
        let config = config(
            spaces: ["1", "work"],
            fallback: "retired"
        )
        #expect(AppRulePin.engagedSpace(config) == SpaceID("1"))
    }

    /// And with nothing to choose there is no answer — the
    /// Space picker is greyed for exactly that state.
    @Test("no Spaces means no pin value at all")
    func emptySpacesHaveNoDefault() {
        #expect(
            AppRulePin.engagedSpace(config(spaces: [])) == nil
        )
    }

    /// The no-Spaces pointer places its link. A remote gate:
    /// nothing on this card can declare a Space, so the reason
    /// names the destination that can. Asserted here rather than
    /// beside its siblings because `CrossReferenceRowSlotTests`
    /// is at the §2.1 ceiling; that suite's register points here.
    @MainActor
    @Test("the no-Spaces pointer places its link")
    func noSpacesProsePlacesItsLink() {
        LocalizationManager.shared.select("en")
        #expect(
            AppRulesSection.noSpacesProse.contains(
                CrossReferenceRow.linkSlot
            )
        )
    }
}
