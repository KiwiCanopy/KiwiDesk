import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A rule must say something (#1022).
///
/// "Tiles normally" on its own is the default behaviour of every
/// unruled app — the card's own empty note says so — so choosing
/// it REQUIRES a Space, and the clear button is withheld while
/// that holds. What that costs is two states where "tiles, no pin" is
/// a real instruction rather than an empty row, and both are
/// asserted here because both are one missing arm away from being
/// broken:
///
/// - **override mode**, where `AppRuleOverride`'s stored nil is
///   the TOMBSTONE — it un-pins an app the base profile pins, and
///   `AppRulesSection.apps` keeps the row drawn for exactly that
///   reason;
/// - **no Spaces declared**, where there is nothing to pin to.
///
/// The verdict is three-cased rather than a `Bool` because a
/// two-state answer shipped a control that was neither held nor
/// settable: live, undimmed, and writing nil on click. That is
/// the state "grey, don't hide" exists to forbid, so
/// `.unavailable` is a case and not the absence of one.
///
/// `AppRulePinWiringTests` is the other half — this suite holds
/// what the decisions ARE, that one holds that the row asks them.
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
            AppRulePin.verdict(
                floats: false,
                isOverride: false,
                hasSpaces: true
            ) == .locked
        )
    }

    @Test("a floating row's pin is free")
    func floatingLeavesThePinOptional() {
        #expect(
            AppRulePin.verdict(
                floats: true,
                isOverride: false,
                hasSpaces: true
            ) == .free,
            Comment(
                rawValue:
                    "\"floats\" says something by itself, so "
                    + "the pin is the user's choice there"
            )
        )
    }

    // MARK: - The two states the rule must not break

    /// The tombstone. A one-armed predicate that forgot this
    /// would withhold the clear button that IS the instruction,
    /// so a profile could no longer un-assign an app its base
    /// assigns.
    @Test("override mode keeps a tiling row's pin releasable")
    func overrideModeNeverLocks() {
        #expect(
            AppRulePin.verdict(
                floats: false,
                isOverride: true,
                hasSpaces: true
            ) == .free,
            Comment(
                rawValue:
                    "the stored nil is the tombstone — \"tiles, "
                    + "no pin\" is a real instruction in "
                    + "override mode"
            )
        )
    }

    /// With no Spaces there is nothing to pin to, and the answer
    /// is `.unavailable` rather than `.free`: `.free` means the
    /// user may set it, and this one cannot be set at all.
    /// It outranks BOTH other arms — a tiling row and an override
    /// row alike — because the absence of a target is not a thing
    /// either of them can overcome.
    @Test("no Spaces makes the pin unavailable, not free")
    func emptySpacesIsUnavailable() {
        for isOverride in [true, false] {
            for floats in [true, false] {
                #expect(
                    AppRulePin.verdict(
                        floats: floats,
                        isOverride: isOverride,
                        hasSpaces: false
                    ) == .unavailable,
                    Comment(
                        rawValue:
                            "floats: \(floats), isOverride: "
                            + "\(isOverride) — nothing to pin to "
                            + "outranks both"
                    )
                )
            }
        }
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

    /// And with nothing to choose there is no answer, which is
    /// what `.unavailable` above is protecting: the flip that
    /// engages a pin has no value to write.
    @Test("no Spaces means no pin value at all")
    func emptySpacesHaveNoDefault() {
        #expect(
            AppRulePin.engagedSpace(config(spaces: [])) == nil
        )
    }

    /// A TOMBSTONED row's prospective Space is the base's own,
    /// outranking the designated fallback. Both channels read this
    /// — the menu draws it and re-assigning writes it — so
    /// falling through to the fallback drew the wrong Space and
    /// then silently REPLACED the inherited one with it rather
    /// than restoring it (ui-designer, 2026-09-22).
    @Test("a tombstone's prospective pin is the base's Space")
    func inheritedSpaceOutranksTheFallback() {
        let config = config(
            spaces: ["1", "work", "media"],
            fallback: "work"
        )
        #expect(
            AppRulePin.engagedSpace(
                config,
                inherited: SpaceID("media")
            ) == SpaceID("media")
        )
        // …and a base pin naming a Space this profile dropped
        // falls through rather than authoring an invisible value,
        // the same rule the fallback takes.
        #expect(
            AppRulePin.engagedSpace(
                config,
                inherited: SpaceID("retired")
            ) == SpaceID("work")
        )
    }

    /// …and that pointer places its link. A remote gate: nothing
    /// on this card can declare a Space, so the reason names the
    /// destination that can. Asserted here rather than beside its
    /// siblings because `CrossReferenceRowSlotTests` is at the
    /// §2.1 ceiling, and because the `.unavailable` arm is why it
    /// is drawn at all; that suite's register points here.
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
