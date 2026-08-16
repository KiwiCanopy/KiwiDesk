import Foundation
import Testing

@testable import KiwiDesk

/// The two-column detail shell's guard (#678 Phase 4, digest
/// §1.1): the panel offer is ONE data set, every offering
/// destination draws a real preview, and the panel's diff list
/// and Home's popover render through the one rows renderer.
@Suite("Detail panel")
struct DetailPanelTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// The offer set, pinned as data: an accidental member is a
    /// panel with an `EmptyView` preview, which the branch test
    /// below cannot see on its own. v1 was owner-scoped to four
    /// (2026-08-09) and pass 5 added Shortcuts, which is the
    /// extension motion #793-#795 each repeat — so a member
    /// arriving here without a branch in the map below is the
    /// failure this pair exists to catch.
    @Test("the offer set is the scoped seven")
    func offerSetIsPinned() {
        #expect(
            SettingsDetailPanelOffer.offering == [
                .gapsAndBorders, .bars, .colors,
                .layoutDefaults, .shortcuts, .advancedColors,
                .spaces,
            ]
        )
        // General's absence is a RULING, not a gap (#795, owner
        // 2026-08-16): its rows are all UserDefaults/readonly/
        // action, so a panel there could only restate the
        // content column and count a structural zero. Pinned
        // here so re-adding it has to argue with this line.
        #expect(
            !SettingsDetailPanelOffer.offers(.general)
        )
    }

    /// Every offering destination has a preview branch that
    /// CONSTRUCTS its renderer — needle through the branch
    /// body (the Monitors lesson: a consult whose branch body
    /// empties passes every count above it).
    @Test("every offered destination draws a real preview")
    func offeredDestinationsDrawPreviews() throws {
        let source = try panelSource()
        let branches: [SettingsDestination: String] = [
            .gapsAndBorders:
                "case.gapsAndBorders:"
                + "GapsBordersPanelPreview(model:model)",
            .bars: "case.bars:BarsPanelPreview(model:model)",
            .colors:
                "case.colors:PaletteScenePanel(model:model)",
            .layoutDefaults:
                "case.layoutDefaults:LayoutPreviewPanel(",
            .shortcuts:
                "case.shortcuts:KeyboardPreviewPanel(model:model)",
            .advancedColors:
                "case.advancedColors:"
                + "AdvancedColorsPanel(model:model)",
            .spaces:
                "case.spaces:SpacesPanelPreview(model:model)",
        ]
        #expect(
            Set(branches.keys)
                == SettingsDetailPanelOffer.offering,
            Comment(
                rawValue:
                    "a destination joined the offer without "
                    + "joining this map — add its branch needle"
            )
        )
        for (destination, needle) in branches {
            #expect(
                source.contains(needle),
                Comment(
                    rawValue:
                        "\(destination) offers a panel but "
                        + "no longer draws its preview"
                )
            )
        }
    }

    /// The panel's diff list is the AREA's slice of the draft
    /// (owner 2026-08-10) — the whole draft lives in Home's
    /// popover, so a Bars panel listing a Gaps edit is the
    /// noise this filter removes. Driven through the census's
    /// own placement so the pick survives key reshuffles, and
    /// the nil-area residue (a key with no Settings surface)
    /// is pinned dropped, not defaulted in.
    @Test("the panel diff list is the area's slice")
    @MainActor
    func diffListIsTheAreasSlice() throws {
        let barsKey = try #require(
            SettingKey.allCases.first {
                $0.placement.area == .bars
            }
        )
        let gapsKey = try #require(
            SettingKey.allCases.first {
                $0.placement.area == .gapsAndBorders
            }
        )
        let rows = [
            SettingsDiffRow.change(
                barsKey,
                label: "bars",
                old: "a",
                new: "b"
            ),
            SettingsDiffRow.change(
                gapsKey,
                label: "gaps",
                old: "a",
                new: "b"
            ),
        ]
        let sliced = SettingsDiffRowSource.areaRows(
            rows,
            in: .bars
        )
        #expect(sliced.map(\.key) == [barsKey])
        // And the panel VIEW consults the filter — the helper
        // alone cannot see its own mount bypassing it with
        // `rows(for:)` directly (guard-prover, 2026-08-10).
        // Keyed on the use site: the needle runs from the one
        // rows fetch through the filter call, so the listed
        // rows, the heading's N and the elsewhere remainder
        // all derive from the same filtered array (the count
        // ruling, owner 2026-08-10).
        let source = try panelSource()
        #expect(
            source.contains(
                "letall=SettingsDiffRowSource.rows(for:model)"
                    + "letrows=SettingsDiffRowSource.areaRows("
                    + "all,in:destination)"
            ),
            Comment(
                rawValue:
                    "the panel no longer routes its diff rows "
                    + "through the area filter"
            )
        )
        if let orphan = SettingKey.allCases.first(where: {
            $0.placement.area == nil
        }) {
            let orphanRow = SettingsDiffRow.note(
                orphan,
                label: "orphan",
                note: "Edited"
            )
            #expect(
                SettingsDiffRowSource.areaRows(
                    [orphanRow],
                    in: .bars
                ).isEmpty
            )
        }
    }

    /// The digest's `›` collapse handle is deliberately NOT
    /// built (owner 2026-08-10): the responsive pass drops the
    /// panel by WIDTH, and a manual collapse beside that is a
    /// persisted preference duplicating what the window
    /// decides. This pin keeps the removal a decision — a
    /// collapse quietly returning must re-argue it here.
    ///
    /// 17a's detached card does NOT re-open that question, and
    /// the line between them is worth stating because it is
    /// one `UserDefaults` key wide: the card's close is
    /// per-mount `@State` cleared on every destination change,
    /// so it answers "not on this screen, right now" and never
    /// "this area has no preview". A stored answer would
    /// survive the window growing back past 1200 and leave a
    /// docked column the user could not explain.
    @Test("the panel has no manual collapse")
    func noManualCollapse() throws {
        let source = try panelSource()
        #expect(!source.contains("collapsed"))
        let shell = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView.swift"
        )
        #expect(!shell.contains("panel_collapsed"))
        #expect(shell.contains("@StatevarpreviewShown:Bool?"))
        #expect(
            shell.contains(
                ".onChange(of:model.destination){_,_in"
                    + "previewShown=nil}"
            )
        )
        // The card's answer never reaches the preferences seam
        // — the one route anything in this shell persists by.
        let preview = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView+Preview.swift"
        )
        #expect(!preview.contains("preferences"))
        #expect(!preview.contains("UserDefaults"))
    }

    /// The in-card mounts the panel replaced stay replaced —
    /// the same fact drawn twice on one screen is the drift
    /// this lane's migration removed. Advanced Colours' own
    /// mounts (the palette mirrors) are deliberately outside
    /// this scan.
    @Test("migrated previews do not return to their cards")
    func migratedPreviewsStayOut() throws {
        let cards: [(String, String)] = [
            (
                "Components/GapsAndBorders/GapsEditor.swift",
                "GapsDiagram("
            ),
            (
                "Components/GapsAndBorders/"
                    + "FocusBorderEditor.swift",
                "FocusBorderPreview("
            ),
            (
                "Components/GapsAndBorders/"
                    + "DragVisualsEditor.swift",
                "DragVisualPreview("
            ),
            // The two bar strips are not listed: #793 took their
            // last mount (Advanced Colours' cards) and the
            // renderers were deleted outright, so a needle for
            // them would assert against a type that no longer
            // exists — permanently true, and read as coverage.
            (
                "Components/Colors/StructureColorCards.swift",
                "FocusBorderPreview("
            ),
            (
                "Components/Colors/StructureColorCards.swift",
                "DragVisualPreview("
            ),
            // #794: the per-space editor gave up its own copy,
            // which is what let the panel take it — the renderer
            // was deleted with the mount, so the needle names the
            // SECTION that must not grow a replacement.
            (
                "Sections/SpacesSection+Overrides.swift",
                "SpaceOverridePreview("
            ),
            (
                "Sections/ColorsMotionSection.swift",
                "PaletteSceneThumbnail("
            ),
            (
                "Sections/LayoutDefaultsSection.swift",
                "LayoutPreviewPanel("
            ),
        ]
        for (file, needle) in cards {
            let source = try squashed(
                "Sources/KiwiDesk/Settings/" + file
            )
            #expect(
                !source.contains(needle),
                Comment(
                    rawValue:
                        "\(file) re-grew \(needle) — the "
                        + "panel owns that preview now"
                )
            )
        }
    }

    /// The census-label seam has ONE runtime reader of the
    /// English manifest: `SettingsCensusLabel`. A second
    /// `LocaleCatalog.load("en")` caller in the GUI would mint
    /// a second cached English copy that drifts from the first
    /// — `LocaleCatalog.load` went public for exactly one
    /// caller class, and this is the guard the rule names.
    @Test("the English manifest has one GUI reader")
    func manifestHasOneReader() throws {
        let root = Self.root.appendingPathComponent(
            "Sources/KiwiDesk"
        )
        var callers: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            scanned += 1
            if source.contains("LocaleCatalog.load(") {
                callers.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 50)
        #expect(callers == ["SettingsCensusLabel.swift"])
    }

    // MARK: - Plumbing

    private func panelSource() throws -> String {
        try squashed(
            "Sources/KiwiDesk/Settings/"
                + "SettingsDetailPanel.swift"
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root.appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        return SourceScan.stripComments(raw)
            .filter { !$0.isWhitespace }
    }
}
