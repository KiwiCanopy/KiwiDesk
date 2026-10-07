import Foundation
import Testing

/// #2024: the front chip's hit area takes every view that draws the
/// chip — the glass and the indicator draw its end pads where no
/// box does — and asks the clip. `BarMenuHeaderTests` drives the
/// area's arithmetic; this pins that the hit hands it those views.
@Suite("Front chip menu wiring (#2024)")
struct FrontChipMenuSeamTests {
    @Test("the hit unions every drawn view and asks the clip")
    func hitTakesEveryDrawnView() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/SpaceBarOverlay+FrontAppMenu.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let count = { (needle: String) in
            source.components(separatedBy: needle).count - 1
        }
        #expect(
            count(
                "frontBox, frontGlass, frontAccentClip, frontIcon,\n"
                    + "            frontGlyph, frontName,"
            ) == 1
        )
        #expect(count("clip: clipped ? itemContainer.frame : nil") == 1)
    }
}
