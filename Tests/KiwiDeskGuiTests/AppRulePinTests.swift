import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A rule must say something (#1022).
///
/// "Tiles normally" on its own is the default behaviour of every
/// unruled app — the card's own empty note says so — so choosing
/// it REQUIRES a Space pin, and the checkbox is locked while it
/// holds. What that costs is two states where "tiles, no pin" is
/// a real instruction rather than an empty row, and both are
/// asserted here because both are one missing `&&` away from
/// being broken:
///
/// - **override mode**, where `AppRuleOverride`'s stored nil is
///   the TOMBSTONE — it un-pins an app the base profile pins, and
///   `AppRulesSection.apps` keeps the row drawn for exactly that
///   reason;
/// - **no Spaces declared**, where there is nothing to pin to, so
///   a locked checkbox would sit over an empty menu.
///
/// The predicate is a pure function precisely so these are
/// reachable: the same three inputs feed the checkbox's disabled
/// state and the float flip's decision to engage a pin, so a
/// divergence between what is locked and what is written is not
/// expressible.
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

    // MARK: - Tiling forces the pin

    @Test("a tiling row's pin is locked")
    func tilingLocksThePin() {
        #expect(
            AppRulePin.isLocked(
                floats: false,
                isOverride: false,
                hasSpaces: true
            )
        )
    }

    @Test("a floating row's pin is free")
    func floatingLeavesThePinOptional() {
        #expect(
            !AppRulePin.isLocked(
                floats: true,
                isOverride: false,
                hasSpaces: true
            ),
            Comment(
                rawValue:
                    "\"floats\" says something by itself, so "
                    + "the pin is the user's choice there"
            )
        )
    }

    // MARK: - The two states the rule must not break

    /// The tombstone. A one-armed predicate that forgot this
    /// would lock the checkbox that IS the instruction, so a
    /// profile could no longer un-pin an app its base pins.
    @Test("override mode keeps a tiling row's pin releasable")
    func overrideModeNeverLocks() {
        #expect(
            !AppRulePin.isLocked(
                floats: false,
                isOverride: true,
                hasSpaces: true
            ),
            Comment(
                rawValue:
                    "the stored nil is the tombstone — \"tiles, "
                    + "no pin\" is a real instruction in "
                    + "override mode"
            )
        )
    }

    /// With no Spaces there is nothing to pin to, so tiling
    /// cannot force a pin and the card points at where to declare
    /// one instead.
    @Test("no Spaces means no forced pin")
    func emptySpacesNeverLocks() {
        #expect(
            !AppRulePin.isLocked(
                floats: false,
                isOverride: false,
                hasSpaces: false
            )
        )
    }

    /// …and that pointer places its link. A remote gate: nothing
    /// on this card can declare a Space, so the reason names the
    /// destination that can. Asserted here rather than beside its
    /// siblings because `CrossReferenceRowSlotTests` is at the
    /// §2.1 ceiling, and because the arm above is why it is drawn
    /// at all; that suite's register points here.
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
            AppRulePin.defaultSpace(config) == SpaceID("media"),
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
        #expect(AppRulePin.defaultSpace(config) == SpaceID("1"))
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
        #expect(AppRulePin.defaultSpace(config) == SpaceID("1"))
    }

    /// And with nothing to choose there is no answer, which is
    /// what the empty-Spaces arm above is protecting: the flip
    /// that engages a pin has no value to write.
    @Test("no Spaces means no pin value at all")
    func emptySpacesHaveNoDefault() {
        #expect(AppRulePin.defaultSpace(config(spaces: [])) == nil)
    }
}
