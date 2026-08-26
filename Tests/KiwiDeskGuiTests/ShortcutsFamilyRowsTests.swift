import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The family-vs-instance half of the Shortcuts census render
/// (#678 Phase 3). `ShortcutsCensusRenderTests` holds WHERE a
/// family sits; this holds WHAT it draws — how many rows, which
/// verb, in what instance order.
///
/// Split from that suite on the 350-line ceiling, at the seam
/// it already marked. The two fail apart: a family can sit in
/// the right container and expand to the wrong rows, and it can
/// expand correctly from a list nothing renders.
@Suite("Shortcuts family expansion")
struct ShortcutsFamilyRowsTests {

    /// The census's unit is a SETTING, and a keybinding family is
    /// one setting however many rows it draws. This is the half
    /// of that rule a type cannot state: every family placed in
    /// the Shortcuts area either expands to rows or is a
    /// hand-drawn container, and none may expand to nothing while
    /// claiming a row tier.
    ///
    /// Pinned against a fixture with a known space list and two
    /// layers, so the per-space and per-layer families expand to
    /// a count this can reason about rather than to whatever the
    /// host happens to have.
    ///
    /// **Which families may answer `nil` is DATA, not a `continue`.**
    /// The renderer reads `renderedRows(for:)`, so `nil` and `[]`
    /// put the same nothing on screen; a loop that skipped `nil`
    /// would let any family vanish silently — the exact failure
    /// this suite exists to catch — while every assertion in it
    /// still passed. `guard-prover` demonstrated that: nilling
    /// `toggleSticky` left every test in the suite green. So the
    /// allow-list is enumerated and the relation asserted in
    /// BOTH directions.
    @Test("only the hand-drawn containers expand to no rows")
    @MainActor
    func familiesExpand() {
        // Every key placed in this area that draws no `NavRow`,
        // for one of two reasons — both legitimate, and neither
        // allowed to grow silently:
        //
        //  - a container the section draws by hand (the layer
        //    strip and the icon row that rides it, the app list,
        //    the raw-Lua list and its Import action);
        //  - the one row here that is not a shortcut at all —
        //    the resize-feedback preference, whose census case
        //    lives in the Behaviour sub-enum and whose control
        //    the Size & float card draws directly.
        let handDrawn: Set<SettingKey> = [
            .shortcuts(.layers),
            .shortcuts(.layersIcon),
            .shortcuts(.openApplications),
            .shortcuts(.advanced),
            .shortcuts(.import),
            .behaviour(.resizeFeedback),
        ]
        let expander = fixture()
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .shortcuts
        }
        #expect(!placed.isEmpty)
        // Vacuity: the allow-list must name real placed keys, or
        // the `iff` below holds over a set that isn't there.
        #expect(handDrawn.isSubset(of: Set(placed)))
        for key in placed {
            let rows = expander.rows(for: key)
            if handDrawn.contains(key) {
                #expect(
                    rows == nil,
                    Comment(
                        rawValue: "\(key.id) is hand-drawn "
                            + "and must expand to nil"
                    )
                )
            } else {
                #expect(
                    rows?.isEmpty == false,
                    Comment(
                        rawValue: "\(key.id) claims a row "
                            + "tier but expands to nothing"
                    )
                )
            }
        }
    }

    /// The per-space families expand once per space, the
    /// per-Desktop ones once per Desktop, and the switch family
    /// once per OTHER layer. A fixture pins the counts: an
    /// expansion that silently collapsed to one row would still
    /// satisfy `familiesExpand`.
    ///
    /// The fixture's two lists are deliberately DIFFERENT
    /// lengths — three spaces, two Desktops — so a Desktop
    /// family wired to the space list (or the reverse) reds
    /// here. Equal lengths would make that swap invisible,
    /// which is the same blindness `moveFamiliesAreDistinct`
    /// exists for one axis over.
    @Test("per-instance families expand per instance")
    @MainActor
    func instanceCounts() {
        let expander = fixture()
        for key in [
            SettingKey.shortcuts(.goToSpace),
            .shortcuts(.moveToSpace),
            .shortcuts(.moveToSpaceFollow),
        ] {
            #expect(
                expander.rows(for: key)?.count
                    == expander.spaces.count,
                "\(key.id) should expand once per space"
            )
        }
        for key in [
            SettingKey.shortcuts(.focusDesktop),
            .shortcuts(.moveToDesktop),
            .shortcuts(.moveToDesktopFollow),
        ] {
            #expect(
                expander.rows(for: key)?.count
                    == expander.desktops.focus.count,
                "\(key.id) should expand once per Desktop"
            )
        }
        #expect(expander.spaces.count > 1)
        #expect(expander.desktops.focus.count > 1)
        #expect(expander.spaces.count != expander.desktops.focus.count)
        // Two layers defined, one of them current, so exactly
        // one switch row.
        #expect(
            expander.rows(for: .shortcuts(.switchToLayer))?
                .count == 1
        )
    }

    /// Each per-space family draws its OWN verb. Set equality
    /// over the order list cannot see this: swapping the two
    /// move families' expansions leaves every count identical
    /// and puts "& follow" rows under the plain heading.
    @Test("the two move-to-space families draw different verbs")
    @MainActor
    func moveFamiliesAreDistinct() {
        let expander = fixture()
        let plain =
            expander.rows(for: .shortcuts(.moveToSpace)) ?? []
        let follow =
            expander.rows(for: .shortcuts(.moveToSpaceFollow))
            ?? []
        #expect(!plain.isEmpty && !follow.isEmpty)
        #expect(
            plain.allSatisfy {
                !$0.lua.contains("move_to_space_and_follow")
            }
        )
        #expect(
            follow.allSatisfy {
                $0.lua.contains("move_to_space_and_follow")
            }
        )
    }

    /// The four resize families each draw their own axis and
    /// direction, and each bakes in the live step (#58). Reading
    /// them by name rather than by index into `resizeAndFloat` is
    /// what this pins: an inserted row used to re-point a family
    /// at its neighbour silently.
    @Test("each resize family draws its own axis and direction")
    @MainActor
    func resizeFamiliesAreDistinct() {
        let expander = fixture()
        let expected: [(SettingKey, String)] = [
            (.shortcuts(.growWidth), #"KiwiDesk.resize("x", 42)"#),
            (
                .shortcuts(.shrinkWidth),
                #"KiwiDesk.resize("x", -42)"#
            ),
            (.shortcuts(.growHeight), #"KiwiDesk.resize("y", 42)"#),
            (
                .shortcuts(.shrinkHeight),
                #"KiwiDesk.resize("y", -42)"#
            ),
        ]
        for (key, lua) in expected {
            #expect(expander.rows(for: key)?.first?.lua == lua)
        }
    }

    /// The per-space move pair renders INTERLEAVED — plain,
    /// follow, plain, follow — because "Move to Space 2" and
    /// "…& follow" are one decision about one space.
    ///
    /// Nothing above can see this. Set equality is order-blind by
    /// design, and splitting the pair into two census families
    /// silently un-paired them on screen with all thirteen tests
    /// green; this is the assertion that would have caught it.
    @Test("the per-space move rows interleave by space")
    @MainActor
    func perSpaceMoveRowsInterleave() {
        let expander = fixture()
        let run = ShortcutsRowOrder.interleavedRun(
            startingAt: .shortcuts(.moveToSpace)
        )
        #expect(run?.count == 2)
        let rendered = expander.renderedRows(
            for: .shortcuts(.moveToSpace)
        )
        #expect(rendered.count == expander.spaces.count * 2)
        // Even indices are the plain verb, odd the follow verb —
        // per space, not two stacked lists.
        for (offset, command) in rendered.enumerated() {
            let isFollow = command.lua.contains(
                "move_to_space_and_follow"
            )
            #expect(
                isFollow == (offset % 2 == 1),
                Comment(rawValue: "row \(offset) is out of pair")
            )
        }
        // The follower draws nothing of its own, or every row
        // would appear twice.
        #expect(
            expander.renderedRows(
                for: .shortcuts(.moveToSpaceFollow)
            )
            .isEmpty
        )
    }

    /// Every run's members share a container and tier, or the
    /// leader would emit rows into a card the follower is not
    /// placed in.
    @Test("interleaved runs stay inside one container and tier")
    func interleavedRunsAreHomogeneous() {
        #expect(!ShortcutsRowOrder.interleavedRuns.isEmpty)
        for run in ShortcutsRowOrder.interleavedRuns {
            #expect(run.count > 1)
            let places = Set(
                run.map {
                    [
                        String(describing: $0.placement.container),
                        String(describing: $0.placement.tier),
                    ]
                }
            )
            #expect(places.count == 1)
        }
    }

    /// The Inactive shortcuts card is the #92 net: a
    /// space-targeting binding whose space left the list is still
    /// Carbon-registered and still blocks the recorder, so it must
    /// stay reachable. The net is only as wide as the families it
    /// re-surfaces, and that list used to be hand-written beside
    /// the expander that owns family→rows — a fifth per-space
    /// family would have compiled, reded the render guard, and
    /// been omitted from the one card that exists to catch it.
    ///
    /// Derived, not re-listed: a family is per-space if its rows
    /// change when the space list does. Anything matching that
    /// must appear in `OrphanedShortcuts.perSpaceFamilies`.
    @Test("the Inactive card covers every per-space family")
    @MainActor
    func inactiveCardCoversPerSpaceFamilies() {
        let one = ShortcutsFamilyRows(
            spaces: ["1"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(
                focus: [1, 2],
                move: [1, 2]
            ),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
        let two = ShortcutsFamilyRows(
            spaces: ["1", "2"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(
                focus: [1, 2],
                move: [1, 2]
            ),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName
        )
        let perSpace = SettingKey.allCases.filter { key in
            key.placement.area == .shortcuts
                && (one.rows(for: key)?.count ?? 0)
                    != (two.rows(for: key)?.count ?? 0)
        }
        #expect(!perSpace.isEmpty)
        #expect(
            Set(perSpace)
                == Set(OrphanedShortcuts.perSpaceFamilies)
        )
    }

    /// The census key that is NOT a keybinding: Size & float's
    /// drawer row is a `TilingSettings` toggle, so it has no
    /// expansion and the card draws it directly. Pinned because
    /// `nil` here means two different things elsewhere (a
    /// hand-drawn container) and only this one is a non-shortcut.
    @Test("the resize-feedback row carries no keybinding rows")
    @MainActor
    func resizeFeedbackIsNotAFamily() {
        #expect(
            fixture().rows(for: .behaviour(.resizeFeedback))
                == nil
        )
    }

    /// Pins the display-independent inputs every expansion
    /// reasons from, so a default that moves reds as a default
    /// rather than as a mysterious count.
    @MainActor
    private func fixture() -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(
                focus: [1, 2],
                move: [1, 2]
            ),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName, "resize"],
            currentLayer: KeyLayer.defaultName
        )
    }
}
