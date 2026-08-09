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
            .layoutDefaults: "LayoutPreviewPanel(",
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

    /// The collapse pick persists — the `›` is remembered
    /// disclosure state (§1.1), not per-visit view state.
    @Test("the collapse pick is a persisted preference")
    func collapsePersists() throws {
        let shell = try squashed(
            "Sources/KiwiDesk/Settings/SettingsView.swift"
        )
        #expect(
            shell.contains(
                "@AppStorage(\"settings.panel_collapsed\")"
            )
        )
    }

    /// Both collapse directions exist: the expanded header
    /// carries the `›` hide, the collapsed strip carries the
    /// `‹` show — an un-reopenable panel is a deleted feature
    /// with a persisted flag.
    @Test("both collapse directions are drawn")
    func collapseChipsAreDrawn() throws {
        let source = try panelSource()
        #expect(source.contains("collapsed=true"))
        #expect(source.contains("collapsed=false"))
        #expect(source.contains("chevron.right"))
        #expect(source.contains("chevron.left"))
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
