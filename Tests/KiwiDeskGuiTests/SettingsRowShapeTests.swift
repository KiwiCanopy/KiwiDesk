import Foundation
import Testing

@testable import KiwiDesk

/// The row axis has ONE application site (#678 turn 17a).
///
/// Every labelled row used to frame its own label to
/// `settingsLabelColumn`, which was harmless while there was
/// one arrangement and is not now: a row that keeps framing its
/// own label keeps the shared column at 820 pt, where the
/// column leaves a segmented control ~90 pt and the control
/// wraps or clips — exactly what 17a's "controls never" is
/// about. The failure is invisible in every other guard,
/// because such a row still compiles, still aligns at 1440 and
/// still reads correctly in review.
///
/// Stated residue: this scans the label COLUMN's application.
/// A row that lays its label out some third way — a `Grid`, a
/// hand-rolled `HStack` with a `Spacer` — is outside what a
/// needle can see, and belongs to review.
@Suite("Settings row shape")
struct SettingsRowShapeTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// Files that may frame a label to a fixed column of their
    /// own, and why. The one copy of who may.
    ///
    /// `ColorField` is here on the standing exception rather
    /// than as an oversight: the colour fields live in their
    /// own two-column grid, deliberately NOT on the shared row
    /// axis (`SettingsMetrics.colorLabelColumn`), so they are
    /// not rows this shape governs.
    ///
    /// The shape's own site is deliberately NOT in this map:
    /// it frames CONDITIONALLY (`stacked ? nil : labelColumn`)
    /// and so matches none of the needles below, which is what
    /// makes an unconditional frame the thing this scan looks
    /// for. That site is pinned by `shapeSwapsLayout` instead.
    ///
    /// `AppRuleIdentity` is out of scope for BOTH reasons at once,
    /// and is named here so it reads as ruled rather than missed
    /// (#1022, #1608): its name column is a LIST's own axis, not
    /// a label beside a control — the same standing exception
    /// `ColorField` takes — and it frames it conditionally, the
    /// shape this clause has just excused.
    private static let allowed: [String: String] = [
        "ColorField.swift":
            "the colour grid's own axis, never the row axis"
    ]

    @Test("only the shape frames a label to the column")
    func oneLabelColumnSite() throws {
        let root = Self.root.appendingPathComponent(
            "Sources/KiwiDesk"
        )
        var framing: [String] = []
        var scanned = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .filter { !$0.isWhitespace }
            scanned += 1
            // Every spelling of "frame a label to a settings
            // column". The override one was missing from the
            // first cut, and an inheriting override row was
            // hand-framing through it — the scan passed for not
            // knowing the word (code review, 2026-08-11). A new
            // column constant joins this list with its site.
            let needles = [
                ".frame(width:labelColumn",
                ".frame(width:SettingsMetrics.labelColumn",
                ".frame(width:overrideLabelColumn",
                ".frame(width:SettingsMetrics.overrideLabelColumn",
                ".frame(width:SettingsMetrics.colorLabelColumn",
                ".frame(width:labelWidth",
            ]
            if needles.contains(where: source.contains) {
                framing.append(file.lastPathComponent)
            }
        }
        #expect(scanned > 50)
        #expect(
            Set(framing) == Set(Self.allowed.keys),
            Comment(
                rawValue:
                    "a row frames its own label column: "
                    + framing.sorted().joined(separator: ", ")
                    + " — route it through SettingsRowShape or "
                    + "argue the exemption in this suite's map"
            )
        )
    }

    /// The shape switches LAYOUT rather than swapping
    /// subtrees, and the label's column goes away entirely
    /// when it stacks. Both halves matter: an `if` here would
    /// tear the control down on every reflow (a menu closes, a
    /// field loses focus mid-drag), and a stacked label still
    /// framed to 210 pt would put the control under a label
    /// that no longer reaches it.
    @Test("the shape swaps the layout, not the subtree")
    func shapeSwapsLayout() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        )
        #expect(source.contains("letstacked=width.stacksRows"))
        #expect(
            source.contains(
                "?AnyLayout(VStackLayout(alignment:.leading,"
                    + "spacing:4)):AnyLayout(HStackLayout())"
            )
        )
        #expect(
            source.contains(
                "letcolumn=stacked||controlTrails?nil:labelColumn"
            )
        )
        #expect(
            source.occurrences(of: ".frame(width:column,alignment:.leading)")
                == 1
        )
    }

    /// `controlTrails` — a compact control trailing (#2439) — is an
    /// argument to the SAME layout swap, never a second layout or
    /// an `if`: it drops the column and lets the label take the
    /// free width, through modifiers that stay in the chain.
    @Test("the trailing option rides the one layout swap")
    func controlTrailsRidesTheSwap() throws {
        let source = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "SettingsRowShape.swift"
        )
        #expect(source.occurrences(of: "AnyLayout(") == 2)
        #expect(source.occurrences(of: "controlTrails") == 3)
        #expect(
            source.contains(
                ".frame(maxWidth:controlTrails?.infinity:nil,"
                    + "alignment:.leading)"
            )
        )
        #expect(!source.contains("ifcontrolTrails"))
    }

    /// The shared row vocabulary goes through the shape. A
    /// row type that stops doing so keeps the wide arrangement
    /// at every width — and the row types are exactly where a
    /// new control gets added, so this is the list that rots.
    @Test("every shared row type takes the shape")
    func sharedRowsTakeTheShape() throws {
        let files = [
            "Components/Common/SettingsRows.swift",
            "Components/Common/SegmentedPicker.swift",
            "Components/Common/SlotSizeRows.swift",
            "Components/GapsAndBorders/GapsEditor.swift",
            // The override chrome's inheriting readout — it
            // framed its own label through the OVERRIDE column
            // and so matched none of the first cut's needles,
            // drawing the wide arrangement inside a list whose
            // live rows stacked (code review, 2026-08-11).
            "Components/SpaceOverrides/OverrideControls.swift",
        ]
        for file in files {
            let source = try squashed(
                "Sources/KiwiDesk/Settings/" + file
            )
            #expect(
                source.contains("SettingsRowShape{")
                    || source.contains("SettingsRowShape(controlTrails:"),
                Comment(
                    rawValue:
                        "\(file) no longer builds its rows "
                        + "through the shape"
                )
            )
        }
    }

    /// The rows whose compact control trails — menus, steppers
    /// and action buttons — while sliders and strips keep the axis
    /// (owner ruling 2026-10-19, #2439). File → how many trailing
    /// shapes it builds; the one copy of who trails.
    private static let trailing: [String: Int] = [
        // Menus.
        "DropdownRow.swift": 1,
        "KiwiShelfCard+Font.swift": 1,
        "SharedLookSection.swift": 1,
        // Steppers: the labelled row, and those a parent labels.
        "StepperRow.swift": 1,
        "GeneralSection+AppWide.swift": 1,
        "KiwiVisionLevelsCard.swift": 2,
        "KiwiVisionLensOverrides.swift": 2,
        // The minimum window size master and its layout rows.
        "MinWindowSizeRows.swift": 2,
        // A Space's own minimum window size (#2422).
        "OverrideMinSizeRow.swift": 1,
        // Titled action rows (AI page, General ▸ Advanced).
        "SettingsActionRow.swift": 1,
        // Every override row's inheriting readout, whatever its
        // live control (#2439, owner eyeball 2026-10-19).
        "OverrideControls.swift": 1,
    ]

    @Test("menus and steppers trail; the register is exact")
    func compactControlsTrail() throws {
        let root = Self.root.appendingPathComponent("Sources/KiwiDesk")
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            .filter { !$0.isWhitespace }
            let name = file.lastPathComponent
            let n = source.occurrences(
                of: "SettingsRowShape(controlTrails:true){"
            )
            if n > 0 { found[name] = n }
        }
        #expect(found == Self.trailing)
        // The menu row adds no `Spacer` of its own, which is what
        // pinned the menu to the axis before.
        let dropdown = try squashed(
            "Sources/KiwiDesk/Settings/Components/Common/"
                + "DropdownRow.swift"
        )
        #expect(!dropdown.contains("Spacer("))
        // Every inheriting override value trails, so the unchecked
        // readouts form one column: no per-row opt-in remains.
        let chrome = try squashed(
            "Sources/KiwiDesk/Settings/Components/SpaceOverrides/"
                + "OverrideControls.swift"
        )
        #expect(!chrome.contains("controlTrails:trailingValue"))
        #expect(!chrome.contains("SettingsRowShape{"))
    }

    private func squashed(_ path: String) throws -> String {
        let url = Self.root.appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .filter { !$0.isWhitespace }
    }
}
