import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// **A colour renders in exactly ONE area** (#678, the Colours
/// phase's tripwire on the Phase 2 interim cards).
///
/// Two editors for one hex is not a cosmetic duplication: each
/// keeps its own disclosure state and its own gate, so the two
/// disagree about whether the value is even editable, and a user
/// who changes it in one place has no way to know the other
/// exists. The interim bar colour cards shipped that on purpose,
/// for one phase, with this guard owed at the end of it.
///
/// **Designed as a lens, not a list** (the #520 lesson): a
/// hand-written "these 25 keys live in Advanced Colours" cannot
/// see key 26. So this scans for the SHAPE — every colour well in
/// the Settings tree — and pins the set of files allowed to
/// contain one. A new swatch anywhere else fails here until
/// someone states why that colour has two homes.
@Suite("One colour, one surface")
struct SettingsColorSurfaceTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// The colour well. `ColorSwatch` is its only other
    /// constructor and is private to `HexColorField`'s own file,
    /// so this one needle covers every editable colour.
    private let well = "HexColorField("

    /// The files that may contain one, each with its reason. The
    /// Advanced Colours row builders are the whole list: the
    /// dispatcher itself renders no well, and `ColorField.swift`
    /// declares the type rather than using it.
    private let allowed: [String: String] = [
        "AdvancedColorRow+Bars.swift":
            "the two bar groups' swatches",
        "AdvancedColorRow+Structure.swift":
            "the border, mark and drag swatches",
        "ColorField.swift":
            "declares HexColorField; not a render site",
    ]

    @Test("every colour well lives in Advanced Colours")
    func colorWellsAreConfinedToTheColoursArea() throws {
        var found = 0
        var offenders: [String] = []
        for file in try SourceScan.swiftSources(under: settingsDir) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits =
                source.components(separatedBy: well).count - 1
            guard hits > 0 else { continue }
            found += hits
            let name = file.lastPathComponent
            if allowed[name] == nil {
                offenders.append("\(name) (\(hits))")
            }
        }
        #expect(
            offenders.isEmpty,
            Comment(
                rawValue:
                    "colour wells outside Advanced Colours: "
                    + offenders.joined(separator: ", ")
                    + " — a colour that renders in two areas has "
                    + "two answers to \"what is this set to\" "
                    + "(#678). Move it, or allow-list the file "
                    + "with a reason."
            )
        )
        // A scan that matched nothing would pass having looked
        // at nothing. Fewer call sites than census rows is
        // correct: the four drag tints share one builder, since
        // both columns edit the same `DragVisual` shape.
        #expect(found >= 20)
    }

    /// An allow-list entry for a file that no longer exists is a
    /// stale excuse quietly widening the net.
    @Test("no allow-list entry outlives its file")
    func allowListIsLive() throws {
        let names = Set(
            try SourceScan.swiftSources(under: settingsDir)
                .map(\.lastPathComponent)
        )
        for (file, reason) in allowed {
            #expect(
                names.contains(file),
                Comment(rawValue: "stale colour exemption: \(file)")
            )
            #expect(!reason.isEmpty)
        }
    }

    /// The other half of "exactly one": every colour the census
    /// places must actually be rendered. The render-parity suite
    /// pins the order lists against the census; this pins that
    /// the area's census rows are the whole colour surface a
    /// palette can paint, so a colour reachable from Lua and from
    /// a palette can never be missing from the one page that
    /// claims to hold all of them.
    @Test("every palette colour has a census row in the area")
    func everyPaletteColorIsPlaced() {
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .advancedColours
        }
        // 25 rows: the 23 a palette carried before this phase,
        // plus the two mark tints it gained with it.
        #expect(placed.count == 25)
        #expect(placed.count == ColorPaletteKeys.all.count)
    }
}
