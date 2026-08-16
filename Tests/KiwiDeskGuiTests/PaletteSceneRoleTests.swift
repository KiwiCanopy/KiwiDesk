import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the palette scene draws, and what it deliberately does
/// not (#793).
///
/// Advanced Colours' whole promise is that the twenty-five
/// colours can be judged TOGETHER, which is unanswerable from
/// four separate group previews. A panel making that promise owes
/// a check that it keeps it — and a SwiftUI body cannot be read
/// for coverage, so `PaletteSceneRoles` states which roles are on
/// the frame and these hold the statement to both the palette
/// surface and the drawing.
///
/// The totality is the point: **every path is drawn or withheld
/// with a reason**, so a colour joining `ColorPaletteKeys` lands
/// in one bucket or reds. Without it a new colour would quietly
/// miss the one page whose subject is seeing them all.
@Suite("Palette scene roles")
struct PaletteSceneRoleTests {
    /// The net. `ColorPaletteKeys.all` is reflection-derived, so
    /// a new colour CodingKey joins the palette surface by
    /// itself — and would otherwise join no picture at all.
    @Test("every palette path is drawn or argued away")
    func panelAccountsForEveryPath() {
        let all = Set(ColorPaletteKeys.all)
        let drawn = PaletteSceneRoles.panel
        let withheld = Set(PaletteSceneRoles.withheld.keys)
        let missing = all.subtracting(drawn.union(withheld))
        #expect(
            drawn.union(withheld) == all,
            Comment(
                rawValue: "unaccounted: "
                    + missing.sorted().joined(separator: ", ")
            )
        )
        // Neither bucket may claim a path the palette does not
        // carry — a typo'd path would otherwise sit in the
        // census forever, drawn by nothing and noticed by
        // nothing.
        #expect(drawn.subtracting(all).isEmpty)
        #expect(withheld.subtracting(all).isEmpty)
        // And no path is in both.
        #expect(drawn.intersection(withheld).isEmpty)
    }

    /// The withheld set is exactly the pointer states, derived
    /// rather than counted: a fifth hover key would join it, and
    /// a NON-hover path appearing there is someone quietly
    /// dropping a colour from the picture behind a reason that
    /// does not apply to it.
    @Test("only pointer states are withheld")
    func onlyHoverIsWithheld() {
        for path in PaletteSceneRoles.withheld.keys {
            #expect(
                path.contains(".hover_"),
                Comment(
                    rawValue:
                        "\(path) is not a pointer state — it "
                        + "cannot borrow the hover argument"
                )
            )
        }
        let hover = ColorPaletteKeys.all.filter {
            $0.contains(".hover_")
        }
        #expect(
            Set(hover) == Set(PaletteSceneRoles.withheld.keys),
            "every hover path is withheld, and only those"
        )
        // Each entry states its own reason; an empty one is the
        // finding, not a formality.
        for (path, reason) in PaletteSceneRoles.withheld {
            #expect(
                !reason.isEmpty,
                Comment(rawValue: "\(path) gives no reason")
            )
        }
    }

    /// The tile stays a tile. #793 grew the PANEL; a thumbnail
    /// that grew with it would trade legibility at 72 pt for
    /// roles nobody can read there.
    ///
    /// Stated structurally rather than as a count: pinning
    /// `tile.count == 7` against a literal set asserts the set
    /// agrees with itself (`rule-authoring.md` ▸ a number-pin
    /// must derive the number). What actually matters is that
    /// one renderer can serve both mounts, and that the tile
    /// never smuggles in a role the panel argued away.
    @Test("the shelf tile stays a strict subset of the panel")
    func tileStaysSmall() {
        let tile = PaletteSceneRoles.tile
        let panel = PaletteSceneRoles.panel
        #expect(tile.isSubset(of: panel))
        #expect(tile != panel, "a tile is not a panel")
        #expect(
            tile.isDisjoint(
                with: Set(PaletteSceneRoles.withheld.keys)
            )
        )
    }

    /// The panel scene fits the column it is drawn in.
    ///
    /// This is the defect that shipped (owner, on device,
    /// 2026-08-16): every metric in the tile is `× scale` where
    /// `scale = height / 72`, so mounting the seven-row panel
    /// composition at `height: 300` asked for a 538 pt drawing
    /// inside a 300 pt frame and it spilled over the diff list
    /// below it. Nothing caught it — a SwiftUI body's overflow
    /// is invisible to every assertion in this tree.
    ///
    /// The arithmetic is now the other way round: the panel
    /// fixes its unit and derives its height. What is pinned
    /// here is that the derived height is a real fit — inside
    /// the panel column's own width budget, and not the
    /// runaway the tile's multiplier produced.
    @Test("the panel scene fits the panel column")
    func panelSceneFitsItsColumn() {
        let height = PaletteSceneThumbnail.panelHeight
        // A real drawing, not a collapsed one.
        #expect(height > 120)
        // And it fits the column: the panel is 392 pt wide less
        // its 22 pt insets, and a scene taller than it is wide
        // stops reading as a desktop.
        let contentWidth = SettingsTheme.panelWidth - 44
        #expect(
            height < contentWidth,
            Comment(
                rawValue:
                    "the scene wants \(height) pt in a "
                    + "\(contentWidth) pt column"
            )
        )
        // The tile is untouched by the panel's unit — the two
        // scales are independent, which is the whole fix.
        let tile = PaletteSceneThumbnail(
            palette: ColorPalette(name: "", colors: [:]),
            scene: .tile
        )
        #expect(tile.scale == 1)
    }

    /// A role declared drawn is actually rendered. The census
    /// could otherwise claim coverage the body never delivers —
    /// the failure mode `LayoutSchematicCountTests` records for
    /// its own lane, where a scan passed on a schematic that had
    /// stopped answering its input.
    ///
    /// Reads BOTH scene files, because the tile and the panel
    /// live apart at the §2.1 ceiling, and asserts its input is
    /// non-empty first — a scan that silently read nothing
    /// passes for having found no violations
    /// (`rule-authoring.md`).
    @Test("every drawn role appears in a scene's drawing")
    func drawnRolesAreRendered() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var source = ""
        for name in [
            "PaletteSceneThumbnail.swift",
            "PaletteSceneThumbnail+Panel.swift",
        ] {
            let url = root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Colors/"
                    + name
            )
            // Comments STRIPPED, like every sibling scan: a
            // commented-out `color("…")` would satisfy the drawn
            // check, and a withheld path merely named in a
            // comment would red the negative one (code review,
            // 2026-08-16; `gui.md` states the rule the same lane
            // already paid for once).
            source += SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
        }
        #expect(source.count > 1000, "the scan read the scenes")
        for path in PaletteSceneRoles.panel {
            #expect(
                source.contains("\"\(path)\""),
                Comment(
                    rawValue:
                        "\(path) is declared drawn but no scene "
                        + "asks for it"
                )
            )
        }
        // The withheld four must appear NOWHERE in the drawing:
        // a hover role on the frame is the assertion this census
        // exists to prevent.
        for path in PaletteSceneRoles.withheld.keys {
            #expect(
                !source.contains("\"\(path)\""),
                Comment(
                    rawValue:
                        "\(path) is withheld but a scene draws "
                        + "it — a still frame cannot show a "
                        + "pointer state"
                )
            )
        }
    }
}
