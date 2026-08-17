import Foundation
import Testing

@testable import KiwiDesk

/// The preview sheet's construction (#859) — the half that is
/// about WHAT it is handed rather than what it decides
/// (`PresetPreviewPlanTests` owns that).
///
/// The load-bearing test here is `theSheetCannotReachTheDraft`.
/// The one line keeping Profiles a CATALOG surface rather than a
/// draft-preview one is "the preset's own `TilingSettings`, never
/// the draft" — it is what `DetailPanelTests` cites for keeping
/// `.profiles` out of `SettingsDetailPanelOffer.offering`, and
/// drawing this sheet from `model.config.settings` would flip that
/// ruling with every other guard in the tree green. Structure is
/// the strongest form of it available: the sheet takes no
/// `SettingsModel` at all, so reaching the draft is not a one-token
/// edit but a new stored property, which the scan below sees.
@Suite("Preset preview sheet")
struct PresetPreviewSheetTests {
    private var settingsDir: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
    }

    /// `path` is relative to `Settings/`.
    private func read(_ path: String) throws -> String {
        try String(
            contentsOf: settingsDir.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Comments stripped and whitespace squashed, so a needle
    /// cannot be satisfied by a comment quoting it and reflowing
    /// the source cannot break one.
    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(try read(path))
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    private static let sheet =
        "Components/Profiles/PresetPreviewSheet.swift"
    private static let section = "Sections/PresetsSection.swift"
    private static let card =
        "Components/Profiles/PresetCard.swift"

    // MARK: - The draft is out of reach

    @Test("the sheet cannot reach the draft")
    func theSheetCannotReachTheDraft() throws {
        let source = try squashed(Self.sheet)
        // Non-empty first: a scan that read nothing passes for
        // having found no violations (rule-authoring.md).
        #expect(source.count > 500)
        for banned in [
            "SettingsModel",
            "model.config",
            "@ObservedObject",
            "@EnvironmentObject",
        ] {
            #expect(
                source.occurrences(of: banned) == 0,
                Comment(
                    rawValue:
                        "PresetPreviewSheet reached for \(banned)"
                        + " — the sheet's object is a catalog "
                        + "entry, and the panel refusal in "
                        + "DetailPanelTests rests on it not "
                        + "being the draft"
                )
            )
        }
    }

    @Test("the sheet draws the preset's own settings")
    func theSheetDrawsThePresetsSettings() throws {
        let source = try squashed(Self.sheet)
        #expect(source.occurrences(of: "settings:layout.settings") == 1)
    }

    // MARK: - What it mounts

    /// A derivation rather than a second copy of 132 — and the
    /// reason the production fallback cannot start standing in for
    /// a moved constant.
    @Test("the sheet's column derives from the tile scale")
    func tileWidthIsTheTileScale() {
        #expect(
            PresetPreviewSheet.tileWidth == SchematicScale.tile.width
        )
    }

    /// The width arithmetic, asserted at column counts the sheet
    /// does NOT ship — with `tileWidth`, `gutter` and `pad` all
    /// `static let`s, no assertion over the shipped four could tell
    /// a derivation from a literal that agrees with it today
    /// (4b's `slotWidth` lesson).
    @Test("the sheet's width is the grid's arithmetic")
    func widthIsDerivedFromTheGrid() {
        let sheet = PresetPreviewSheet.self
        // Each extra column adds one tile plus one gutter, at
        // every count — the property, not the shipped value.
        for columns in 1...7 {
            #expect(
                sheet.width(forColumns: columns + 1)
                    - sheet.width(forColumns: columns)
                    == sheet.tileWidth + sheet.gutter
            )
        }
        // One column is a tile between two paddings and the
        // scroller allowance, no gutter.
        #expect(
            sheet.width(forColumns: 1)
                == sheet.tileWidth + 2 * sheet.pad + sheet.scroller
        )
        #expect(
            sheet.width(forColumns: 0)
                == 2 * sheet.pad + sheet.scroller
        )
    }

    /// Four columns is a claim about the narrowest window, so it is
    /// asserted against that window rather than restated.
    @Test("the column count is the most the window can host")
    func columnCountFitsTheNarrowestWindow() {
        let fits = PresetPreviewSheet.width(
            forColumns: PresetPreviewSheet.columns
        )
        #expect(fits <= SettingsWidthClass.minimum)
        // …and it is the MOST that fits: one more would not.
        let oneMore = PresetPreviewSheet.width(
            forColumns: PresetPreviewSheet.columns + 1
        )
        #expect(oneMore > SettingsWidthClass.minimum)
    }

    /// The height bounds, and the one of them that is a RELATION.
    ///
    /// `minHeight` has to stay under the shell's own minimum
    /// content height, or the sheet cannot be shown whole in the
    /// narrowest window the app allows — asserted against
    /// `SettingsWidthClass.minimumHeight` rather than against 400,
    /// which is the half the width bound already got right and the
    /// height bound did not. The comment there claimed the max
    /// "stops it short of filling the window"; the shell floor is
    /// 540 and the window OPENS at 620, so it was false at both
    /// (code review, 2026-08-17).
    @Test("the sheet's floor fits the narrowest window")
    func heightBoundsAreOrderedAndFit() {
        let sheet = PresetPreviewSheet.self
        #expect(sheet.minHeight < SettingsWidthClass.minimumHeight)
        #expect(sheet.minHeight < sheet.idealHeight)
        #expect(sheet.idealHeight < sheet.maxHeight)
    }

    /// The grid STATES its columns rather than adapting to them.
    ///
    /// `.adaptive` seated four with exactly 0 pt of slack, so any
    /// content inset — a legacy scroller once the `ScrollView`
    /// overflows — silently re-wrapped to three, which is the
    /// cross-preset comparison the fixed width exists for
    /// (architect + code review, 2026-08-17). Asserted on the
    /// arithmetic AND on the spelling, because the two fail apart:
    /// the slack could return without `.adaptive` coming back.
    @Test("the grid states four columns, with no reliance on slack")
    func gridStatesItsColumns() throws {
        let source = try squashed(Self.sheet)
        #expect(source.occurrences(of: ".fixed(Self.tileWidth)") == 1)
        #expect(source.occurrences(of: ".adaptive(") == 0)
        #expect(source.occurrences(of: "count:Self.columns") == 1)
        // **There is width to LOSE.** The first cut spent the
        // whole content box on tiles and pinned that equality, so
        // a legacy scroll bar clipped the fourth tile instead of
        // re-wrapping it — `.fixed` had removed the re-wrap and
        // not its cause (re-review, 2026-08-17). The slack is the
        // scroller's, and it is asserted as an INEQUALITY plus its
        // size, so shrinking the reserve reds rather than merely
        // moving which symptom appears.
        let sheet = PresetPreviewSheet.self
        let content =
            sheet.width(forColumns: sheet.columns) - 2 * sheet.pad
        let tiles =
            CGFloat(sheet.columns) * sheet.tileWidth
            + CGFloat(sheet.columns - 1) * sheet.gutter
        #expect(content >= tiles)
        #expect(content - tiles == sheet.scroller)
        // A legacy scroll bar on macOS is ~15 pt, so the reserve
        // has to cover one with nothing left owing.
        #expect(sheet.scroller >= 15)
    }

    /// `.panel` is 240 pt tall and pane-filling; Command Center
    /// draws ten models, so a sheet of panels would be metres
    /// long. `.tile` at its own size is 1.8× the factor the card
    /// refused and above the tour's eye-confirmed floor.
    @Test("the sheet mounts .tile, and states its window count")
    func theSheetMountsTheTileScale() throws {
        let source = try squashed(Self.sheet)
        #expect(source.occurrences(of: "scale:.tile") == 1)
        #expect(source.occurrences(of: "scale:.panel") == 0)
        #expect(
            source.occurrences(
                of: "windows:LayoutSchematic.defaultWindowCount"
            ) == 1
        )
    }

    // MARK: - How it is presented

    /// Hosted on the section and presented by `item:`.
    ///
    /// Both halves matter and they fail apart. `isPresented:` would
    /// build the content from state written in the same tick
    /// (#843); hosting it inside the `LazyVGrid`'s cards would give
    /// the presentation a lifetime the presenter does not control,
    /// which is the shape `SettingsView` avoids for the one discard
    /// dialog by hosting it above the branch that tears it down.
    @Test("the sheet is presented by item, from the section")
    func presentedByItemFromTheSection() throws {
        let source = try squashed(Self.section)
        #expect(source.count > 500)
        #expect(
            source.occurrences(of: ".sheet(item:$previewRequest)") == 1
        )
        #expect(source.occurrences(of: ".sheet(isPresented:") == 0)
        // The sheet does not present itself.
        #expect(try squashed(Self.sheet).occurrences(of: ".sheet(") == 0)

        // And the card is what asks. Needled on the USE site
        // rather than on the request type's declaration, which is
        // in the sheet's own file and would match there — the
        // authoring rule Monitors paid for (a bare `overflowChip(`
        // matched the helper's declaration while the call site
        // went hand-rolled).
        let card = try squashed(Self.card)
        #expect(card.count > 500)
        #expect(card.occurrences(of: "onPreview(") == 1)
        #expect(card.occurrences(of: "PresetPreviewRequest(") == 1)
    }

    /// Previewing is never gated — the one row on this card
    /// without a gate, and deliberately so: the states that grey
    /// Apply (wrong screen count, editing a stored profile) are
    /// exactly when a user most wants to look.
    @Test("the preview row declares no gate")
    func thePreviewRowIsNeverGated() {
        let placement = ProfilesKey.presetsLayouts.placement
        #expect(placement.gate == nil)
        #expect(placement.area == .profiles)
        #expect(placement.container == .presets)
        #expect(placement.tier == .atRest)
        // Its neighbour's gate is what makes the absence a
        // decision rather than an oversight.
        #expect(ProfilesKey.presetsApply.placement.gate != nil)
    }
}
