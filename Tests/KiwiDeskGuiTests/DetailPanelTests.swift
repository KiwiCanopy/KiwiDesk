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

    /// v1's owner-scoped offer set (2026-08-09). Pinned as
    /// data: pass 5 (the keyboard) EXTENDS this deliberately —
    /// an accidental member is a panel with an `EmptyView`
    /// preview, which the branch test below cannot see on its
    /// own.
    @Test("the offer set is the scoped four")
    func offerSetIsPinned() {
        #expect(
            SettingsDetailPanelOffer.offering == [
                .gapsAndBorders, .bars, .colors,
                .layoutDefaults,
            ]
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
    @Test("the panel has no manual collapse")
    func noManualCollapse() throws {
        let source = try panelSource()
        #expect(!source.contains("collapsed"))
        let shell = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView.swift"
        )
        #expect(!shell.contains("panel_collapsed"))
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
            (
                "Components/Bars/SpaceBarCard.swift",
                "SpaceBarPreviewStrip("
            ),
            (
                "Components/Bars/AppBarCard.swift",
                "AppBarPreviewStrip("
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
