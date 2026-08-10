import Foundation
import Testing

@testable import KiwiDesk

/// The focused-stroke honesty wiring (owner ruled 2026-08-10):
/// an ACTIVE schematic tile marks focus with the draft's real
/// `border.focused_color`, threaded through the ONE mount
/// (`LayoutSchematicView`) as an environment value the tiles
/// consult. Needles on the use sites, comment-stripped and
/// whitespace-squashed — every one of these is a surfacing-class
/// wire: delete it and the tiles fall back to the family stroke
/// with every other suite green (the Monitors lesson).
@Suite("Schematic focus stroke wiring")
struct SchematicFocusStrokeTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private static let needles: [String: [String]] = [
        "Components/Layouts/LayoutSchematicView.swift": [
            // The one mount SETS the environment…
            "schematic.environment(\\.schematicFocusStroke,"
                + "focusStroke)",
            // …from the draft's border style, only while
            // borders are enabled…
            "guardstyle.enabledelse{returnnil}",
            // …and floors a plate mount's colour against the
            // plate before showing it there.
            "!HomeCardPlate.plateLegible(style.focusedColor)",
        ],
        "Components/Layouts/LayoutSchematicKit.swift": [
            // Both tile shapes CONSULT it on their active arm.
            "active?focusStroke??palette?.stroke"
        ],
        "Components/Layouts/MonocleSchematic.swift": [
            // Monocle's front card IS its focus mark and
            // consults like every active tile — the strip must
            // not show two focus colours (code review
            // 2026-08-10, which caught it drawing brand green
            // beside honest siblings).
            "front?focusStroke??LayoutSchematic.stroke"
        ],
    ]

    @Test("the mount sets the stroke and the tiles consult it")
    func focusStrokeIsWired() throws {
        for (file, wants) in Self.needles {
            let url = Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/\(file)"
            )
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            #expect(!wants.isEmpty)
            for want in wants {
                #expect(
                    source.contains(want),
                    Comment(
                        rawValue:
                            "\(file) lost its focus-stroke "
                            + "wire: \(want)"
                    )
                )
            }
        }
        // The kit needle must hold for BOTH tile shapes — one
        // occurrence is a tile that fell back silently.
        let kit = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/"
                + "Components/Layouts/LayoutSchematicKit.swift"
        )
        let kitSource = SourceScan.stripComments(
            try String(contentsOf: kit, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(
            kitSource.occurrences(
                of: "active?focusStroke??palette?.stroke"
            ) == 2,
            "SchematicTile and SchematicPileTile each consult"
        )
    }
}
