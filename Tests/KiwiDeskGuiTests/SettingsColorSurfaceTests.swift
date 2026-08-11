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

    /// The other half of "exactly one": the page that claims to
    /// hold every colour has as many rows as there are colours a
    /// palette can carry.
    ///
    /// **Two counts, not two sets** — state the limit rather
    /// than let the docstring over-claim. The census's row keys
    /// (`settings.spaceBarStyle.itemColor`) and the palette's
    /// paths (`space_bar.item_color`) are different vocabularies,
    /// and deriving one from the other here would be a second
    /// copy of `ColorPaletteKeys`' own mapping — worse than the
    /// gap it closes. So a census row with no palette path AND a
    /// palette path with no row would cancel out and pass. What
    /// this does catch is either one alone, which is the way it
    /// actually goes wrong.
    ///
    /// Both halves earn their place, proven to fail apart: drop
    /// a palette path and only the derived comparison reds; grow
    /// the census and the palette surface together — which is
    /// what adding a colour setting does — and only the literal
    /// notices the page got bigger. The literal is a
    /// conscious-edit tripwire over a derived value, not a
    /// restated constant.
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

    /// Which colours accept the empty "Automatic" value has two
    /// homes: `ColorPaletteKeys.allowsAutomatic` in Core, and the
    /// `automatic: true` the row builder hands its swatch. Only
    /// the Core half was pinned, so a `_color` row given the flag
    /// would let the GUI write an empty value that `apply`
    /// silently drops on the next palette round-trip.
    ///
    /// Counted across the WHOLE Settings tree, not one builder: a
    /// guard-prover run put the flag on the App Bar's Fill
    /// swatch — a `_color` path, precisely the defect above — and
    /// a scan confined to the mark rows' own file stayed green.
    ///
    /// **Both assertions earn their place, and they fail apart in
    /// both directions** (proven): the derived comparison alone
    /// catches Core's predicate widening under a static GUI; the
    /// literal alone catches the two halves growing TOGETHER, a
    /// third mark struct plus a third flagged row, which the
    /// derived comparison cannot see. The literal is a
    /// conscious-edit tripwire over a derived value, not a
    /// restated constant.
    @Test("only the mark rows offer Automatic")
    func automaticFlagMatchesTheColorSurface() throws {
        // The ARGUMENT, not the literal `automatic: true`: a
        // swatch given `automatic: someExpression` would
        // contribute zero to a literal count and pass silently,
        // which is a fail-open in a guard whose whole job is to
        // catch a wrongly-flagged row. The excluded files are
        // the ones that DECLARE and plumb the parameter rather
        // than hand it to a swatch — every other occurrence in
        // the tree is a call site. There are two of them since
        // the §2.1 split moved the right-click clear path into
        // `ColorField+AutomaticMenu.swift`, which takes the flag
        // as a parameter and passes it along; the exclusion is
        // by that role, so a THIRD file appearing here should be
        // read as a call site until shown otherwise.
        let plumbing: Set<String> = [
            "ColorField.swift",
            "ColorField+AutomaticMenu.swift",
        ]
        var flags = 0
        for file in try SourceScan.swiftSources(under: settingsDir)
        where !plumbing.contains(file.lastPathComponent) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            flags +=
                source.components(separatedBy: "automatic:")
                .count - 1
        }
        let automaticPaths = ColorPaletteKeys.all.filter(
            ColorPaletteKeys.allowsAutomatic
        )
        #expect(flags == automaticPaths.count)
        #expect(flags == 2)
    }
}
