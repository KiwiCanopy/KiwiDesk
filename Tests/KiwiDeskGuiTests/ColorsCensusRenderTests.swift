import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The two colour areas render FROM the census (#678 Phase 3):
/// the census owns placement, `ColorsRowOrder` owns display
/// order. These pin the two together — every `.coloursAndMotion`
/// / `.advancedColours` census key appears in exactly the order
/// list its placement names, so a census row added, retiered or
/// moved without a renderer update is a red test, not a silently
/// missing control.
///
/// Set equality, not sequence: ORDER is the renderer's to own and
/// is deliberately not pinned here, exactly as in
/// `BarsCensusRenderTests`.
@Suite("Colours render ↔ census parity")
struct ColorsCensusRenderTests {
    private func censusRows(
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == area
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    private func pin(
        _ rendered: [SettingKey],
        _ area: SettingsArea,
        _ container: SettingsContainer,
        _ tier: SettingTier,
        _ what: Comment
    ) {
        #expect(
            Set(rendered) == censusRows(area, container, tier),
            what
        )
        #expect(rendered.count == Set(rendered).count, what)
    }

    // MARK: - Colours & Animations

    /// The shelf's at-rest half, hand-listed on purpose. Its
    /// four affordances are four different shapes — a tile grid,
    /// a link hanging under one tile, a trailing add-tile and a
    /// header button — so there is no order list to compare
    /// against, and a `ForEach` invented to create one would be
    /// a worse renderer rather than a census-driven one.
    ///
    /// A hand list is itself one more place to forget (the #520
    /// caveat), and it is taken here because the alternative is
    /// no net at all: a palette action added to the census with
    /// no shelf affordance would otherwise ship invisible.
    @Test("the palette shelf's at-rest actions are the census's")
    func palettesAtRest() {
        #expect(
            censusRows(.coloursAndMotion, .palettes, .atRest)
                == [
                    .colours(.paletteApply),
                    .colours(.paletteNeonGlowHint),
                    .colours(.paletteSave),
                    .colours(.paletteImport),
                ]
        )
    }

    /// The per-palette context menu. `.showMore` is the nearest
    /// true tier for a menu (not visible at rest, one interaction
    /// away) and the census says so in prose; what this pins is
    /// that the menu and the census agree on WHICH actions hide
    /// there — an action added to the menu with no census row
    /// reds here.
    @Test("the palette context menu is the census's show-more set")
    func palettesContextMenu() {
        pin(
            ColorsRowOrder.palettesContextMenu,
            .coloursAndMotion,
            .palettes,
            .showMore,
            "palette context menu"
        )
    }

    /// The look shelf's at-rest half, hand-listed for the palette
    /// shelf's reason (#1684): a tile grid, the "Keep previous
    /// colors" row a click surfaces (#1752), a trailing add-tile and
    /// a header button.
    @Test("the look shelf's at-rest actions are the census's")
    func looksAtRest() {
        #expect(
            censusRows(.coloursAndMotion, .looks, .atRest)
                == [
                    .colours(.lookApply),
                    .colours(.lookKeepPreviousColors),
                    .colours(.lookSave),
                    .colours(.lookImport),
                ]
        )
    }

    @Test("the look context menu is the census's show-more set")
    func looksContextMenu() {
        pin(
            ColorsRowOrder.looksContextMenu,
            .coloursAndMotion,
            .looks,
            .showMore,
            "look context menu"
        )
    }

    @Test("the Motion card's two tiers are the census's")
    func motionTiers() {
        pin(
            ColorsRowOrder.motionAtRest,
            .coloursAndMotion,
            .motion,
            .atRest,
            "motion at rest"
        )
        // The drawer draws its rows in two lists: the ones under
        // the master's grey and the shelf glide's outside it
        // (#1838); one tier, two orders.
        pin(
            ColorsRowOrder.motionMore + ColorsRowOrder.motionShelf,
            .coloursAndMotion,
            .motion,
            .showMore,
            "motion drawer"
        )
    }

    /// The area's greying container gates are exactly the two OS
    /// accessibility flags — the Motion card under Reduce Motion,
    /// the Liquid Glass card under Reduce transparency (#1418) —
    /// each read from `@Environment` at its card and pinned by
    /// its dim and anchor needles (gui.md). DERIVED over the
    /// area's containers, so a third gated container reds here
    /// until it joins both needles. The glass row's own gate
    /// stays the pre-26 HIDE, which greys nothing.
    @Test("the accessibility greys are the area's only container gates")
    func accessibilityGreysAreContainerGates() {
        let gated = Dictionary(
            uniqueKeysWithValues: containers(of: .coloursAndMotion)
                .compactMap { container in
                    container.gate.map { (container, $0) }
                }
        )
        #expect(
            gated == [
                .motion: .runtime(.reduceMotion),
                .glass: .runtime(.reduceTransparency),
            ]
        )
        #expect(SettingRuntimeGate.reduceTransparency.greys)
        #expect(!SettingRuntimeGate.liquidGlassUnavailable.greys)
    }

    /// The area's render knows exactly its five containers — the
    /// Shared look card first since #1752; another would mount
    /// nowhere, so it must fail loud here rather than ship an
    /// unreachable row.
    @Test("Looks & Animations holds its five containers")
    func coloursAndMotionContainers() {
        #expect(
            containers(of: .coloursAndMotion)
                == [.sharedLook, .looks, .palettes, .glass, .motion]
        )
    }

    // MARK: - Advanced Colours

    /// Every Advanced Colours group draws its rows at rest:
    /// the page is a browse, and since #1857 nothing on it hides
    /// behind a drawer.
    @Test("each Advanced Colours group's rows are the census's")
    func advancedColoursGroups() {
        // Each role group draws its colour above its rows.
        pin(
            [ColorRole.accent.paint] + ColorsRowOrder.accentAtRest,
            .advancedColours,
            .accent,
            .atRest,
            "accent"
        )
        pin(
            [ColorRole.secondAccent.paint]
                + ColorsRowOrder.secondAccentAtRest,
            .advancedColours,
            .secondAccent,
            .atRest,
            "second accent"
        )
        pin(
            ColorsRowOrder.kiwishelfAtRest,
            .advancedColours,
            .kiwishelf,
            .atRest,
            "shelf inks"
        )
        pin(
            ColorsRowOrder.windowMarksAtRest,
            .advancedColours,
            .windowMarks,
            .atRest,
            "window marks"
        )
        #expect(
            SettingKey.allCases.filter {
                $0.placement.area == .advancedColours
                    && $0.placement.tier != .atRest
            }
            .isEmpty
        )
    }

    /// The two role groups are the two colour-vision pairs, one
    /// half of each in each group (#1857): side by side, the
    /// colours that must stay apart are read together. A pair
    /// split onto one side, or moved off the page's top, reds.
    @Test("each role group holds one half of both pairs")
    func roleGroupsSplitThePairs() {
        let accent = ColorsRowOrder.accentAtRest
        let second = ColorsRowOrder.secondAccentAtRest
        #expect(accent.contains(.kiwishelf(.activeItemColor)))
        #expect(second.contains(.spaceBar(.spaceBarFocusedItemColor)))
        #expect(accent.contains(.borders(.dragGhostBorderColor)))
        #expect(second.contains(.borders(.dragDropZoneBorderColor)))
        // Each group leads with the colour its pair is anchored on.
        #expect(accent.first == ColorRole.accent.anchor)
        #expect(second.first == ColorRole.secondAccent.anchor)
        // Every tint of a drag visual sits with its visual: the
        // ghost's in Accent, the drop zone's in Second accent,
        // derived from the key rather than re-listed.
        let drag = SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
                && $0.id.contains("drag")
        }
        #expect(drag.count == 4)
        for key in drag {
            let ghost = key.id.contains("dragGhost")
            #expect(
                (ghost ? accent : second).contains(key),
                "\(key.id) left its visual's group"
            )
        }
    }

    /// Four groups, matching the four cards on screen. A fifth
    /// container placed in this area would render nowhere.
    @Test("Advanced Colours holds exactly the four groups")
    func advancedColoursContainers() {
        #expect(
            containers(of: .advancedColours)
                == [.accent, .secondAccent, .kiwishelf, .windowMarks]
        )
    }

    private func containers(
        of area: SettingsArea
    ) -> Set<SettingsContainer> {
        Set(
            SettingKey.allCases
                .filter { $0.placement.area == area }
                .compactMap { $0.placement.container }
        )
    }
}
