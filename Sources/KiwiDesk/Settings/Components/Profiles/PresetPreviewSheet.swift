import KiwiDeskCore
import SwiftUI

/// One request to open the preview sheet.
///
/// Presented through `.sheet(item:)` rather than `isPresented:`,
/// for the reason `NameEditRequest` already records (#843): the
/// builder is handed this value, so the content can never be built
/// from parent state written in the same tick, and a fresh `id`
/// gives each presentation its own `@State`. It matters more here
/// than for a popover — the cards live in a `LazyVGrid`, which
/// tears down the rows it scrolls past, so a presentation bound to
/// a card's own state has a lifetime the card does not control.
///
/// It carries `liveSizes` so the sheet resolves its modes against
/// the same hardware the card's glyph did. A sheet that read the
/// live displays for itself would be the second derivation
/// `PresetPreviewPlan` exists to prevent.
struct PresetPreviewRequest: Identifiable {
    let id: UUID
    let layout: StandardLayout
    let liveSizes: [CGSize]?

    init(layout: StandardLayout, liveSizes: [CGSize]?) {
        self.id = UUID()
        self.layout = layout
        self.liveSizes = liveSizes
    }
}

/// The preset preview sheet (#859): the layouts a preset actually
/// opens, drawn by the real `LayoutSchematic` family at a size
/// where they read.
///
/// **Why a sheet and not the detail panel.** The panel's object is
/// the DRAFT and this picture is of a catalog entry, and the panel
/// column is dropped by width — sound for a preview redundant with
/// the controls beside it, unsound for a fact stated nowhere else.
/// `.profiles` is deliberately absent from
/// `SettingsDetailPanelOffer.offering` and `DetailPanelTests` pins
/// the refusal with all three grounds; the ruling is argued in
/// `docs/design-decisions.md`.
///
/// **Drawn from the preset's own `TilingSettings`, never the
/// draft.** That one line is what keeps Profiles a CATALOG surface
/// rather than a draft-preview one, and drawing it from
/// `model.config.settings` would flip the panel refusal above
/// without anything noticing. `PresetPreviewSheetTests` ▸ the sheet
/// draws the preset's own settings is what notices.
///
/// **`.tile` at its own size, never a third `SchematicScale`.** A
/// factor over `.tile` is the settled expression for a smaller
/// mount (`HomeCardSchematicBand` at 70/84, the tour at 46/84);
/// this sheet is the case that needs no factor at all, which is
/// precisely #859's argument — a 200 pt card cannot hold a legible
/// schematic and a sheet can. Captions stay suppressed at `.tile`
/// by #753's ruling, so the mode's name is the tile's own label.
struct PresetPreviewSheet: View {
    let layout: StandardLayout
    /// The live screens, or nil where the sheet opened from the
    /// "For other setups" drawer — threaded through to the plan
    /// unchanged, never re-derived here.
    let liveSizes: [CGSize]?
    let onDone: () -> Void

    /// `.tile`'s fixed width, so the grid's column derives from
    /// the schematic it mounts rather than restating a number.
    ///
    /// The `132` is unreachable: `SchematicScale.width` answers
    /// non-nil for `.tile` by construction and nil only for
    /// `.panel`, which this sheet does not mount.
    /// `PresetPreviewSheetTests` asserts the two are equal, so the
    /// fallback cannot start standing in for a moved constant.
    static let tileWidth = SchematicScale.tile.width ?? 132
    static let gutter: CGFloat = 12
    static let pad: CGFloat = 12

    /// The content width that fits exactly `columns` tiles.
    ///
    /// The sheet's width is DERIVED from this rather than picked:
    /// the grid's job is comparison, and a sheet whose column
    /// count changes as the window resizes makes two presets look
    /// different for a reason that is not about them.
    static func width(forColumns columns: Int) -> CGFloat {
        CGFloat(columns) * tileWidth
            + CGFloat(max(columns - 1, 0)) * gutter
            + 2 * pad
    }

    /// Four, which is what the arithmetic allows at the narrowest
    /// window this app has. `SettingsWidthClass.minimum` is 720,
    /// and five columns need 732 — so five would be a width the
    /// sheet could not always have, and the column count would
    /// drop on a narrow desk. Four fits everywhere, and every
    /// shipped preset puts at most four Spaces on one screen, so
    /// at four columns each screen group is exactly one row.
    static let columns = 4

    /// The sheet's height bounds.
    ///
    /// **`minHeight` is a RELATION, not a taste**: it has to stay
    /// under the shell's own minimum content height or the sheet
    /// cannot be shown whole in the narrowest window the app
    /// allows. `PresetPreviewSheetTests` asserts it against
    /// `SettingsWidthClass.minimumHeight` rather than against 400.
    ///
    /// The ideal is the tall shipped case — one row per screen plus
    /// header and footer — so no catalog preset scrolls on an
    /// ordinary window. Past the max the sheet stops growing and
    /// the `ScrollView` takes over, which is also what happens on a
    /// window shorter than the ideal: macOS clamps a sheet to its
    /// parent, so the `ScrollView` is not optional.
    ///
    /// An earlier comment here claimed the max "stops it short of
    /// filling the window". That was false at both of the repo's
    /// own pinned heights — the shell floor is 540 and the window
    /// OPENS at 620 (code review, 2026-08-17). The bound is a
    /// growth stop, not a promise about the window.
    static let minHeight: CGFloat = 400
    static let idealHeight: CGFloat = 600
    static let maxHeight: CGFloat = 780

    private var plan: PresetPreviewPlan {
        PresetPreviewPlan(layout: layout, liveSizes: liveSizes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView { screenGroups }
            Divider()
            footer
        }
        // The sheet states its own size, and states it as
        // arithmetic over the grid it holds.
        //
        // **Width is FIXED at four columns.** Not a range: the
        // grid exists to be compared across presets, and a column
        // count that follows the window would redraw the same
        // preset differently on two desks. Four is the most the
        // narrowest window can host (see `columns`), and it makes
        // every shipped preset's screen group exactly one row.
        //
        // **Height grows, bounded** — see the three constants,
        // which carry what each bound is for and which of them is a
        // relation to the shell rather than a choice.
        //
        // It reads no window size to do any of this. A percentage
        // of the window would be a second measurement site — the
        // drift `SettingsWidthClass` exists to end — and a bounded
        // ideal gets the same picture without one.
        .frame(
            minWidth: Self.width(forColumns: Self.columns),
            maxWidth: Self.width(forColumns: Self.columns),
            minHeight: Self.minHeight,
            idealHeight: Self.idealHeight,
            maxHeight: Self.maxHeight
        )
        .background(SettingsTheme.card)
        // Escape. See `footer` for why the button cannot carry it.
        .onExitCommand(perform: onDone)
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(layout.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                if layout.isStandard {
                    BadgeChip(label: standardBadge)
                }
            }
            Text(layout.displaySummary)
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.pad)
    }

    /// The same key the card's badge is authored with — one badge,
    /// one noun. Two call sites of one key with identical English
    /// is what `extract-keys` allows; only differing English at
    /// two sites is drift, and it fails loudly on that.
    private var standardBadge: String {
        L("presets.standard_badge", "standard")
    }

    private var screenGroups: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(plan.drawnGroups) { group in
                screenGroup(group)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.pad)
    }

    /// One screen's heading over its spaces.
    ///
    /// The heading is the SCREEN and the label under each tile is
    /// its mode, rather than a "screen · mode" pair per tile: on a
    /// one-screen preset — which is three of the seven, and the
    /// ones most likely to be opened — a per-tile pair repeats the
    /// same two words on every row of the grid, and Command Center
    /// would repeat them ten times over three screens.
    private func screenGroup(
        _ group: PresetPreviewPlan.Group
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // `.secondary` matches the sibling sub-group heading
            // `PresetsSection.otherCountGroup` already draws, and
            // no ancestor here sets a foreground for it to derive
            // the wrong colour from.
            Text(presetScreenName(group.screen))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: tileColumns,
                alignment: .leading,
                spacing: Self.gutter
            ) {
                ForEach(group.slots) { tile($0) }
            }
        }
    }

    /// `Self.columns` STATED, never adapted.
    ///
    /// It was `.adaptive(minimum: tileWidth)`, which seated four
    /// columns with exactly **0 pt** of slack: the content width is
    /// `588 - 2*pad = 564` and four tiles plus three gutters is
    /// 564. So any content inset at all — a legacy scroller once
    /// the `ScrollView` overflows, a `pad` change — silently
    /// re-wrapped to three columns, which is the "one preset drawn
    /// differently on two desks" the width comment forbids, arriving
    /// by the route the comment did not consider (architect + code
    /// review, 2026-08-17). `.fixed` cannot re-wrap, and it is the
    /// same reasoning `PresetsSection` records for taking
    /// `.flexible` over `.adaptive`: `.adaptive` cannot express "at
    /// most N".
    ///
    /// `.top` rather than `.topLeading`: the cells centre their
    /// pictures, for the reason `tile(_:)` states.
    private var tileColumns: [GridItem] {
        Array(
            repeating: GridItem(
                .fixed(Self.tileWidth),
                spacing: Self.gutter,
                alignment: .top
            ),
            count: Self.columns
        )
    }

    /// One space: its schematic, then the layout's name under it —
    /// the pairing `LayoutStrip` already draws, so a mode named
    /// beside a schematic reads the same in both places.
    ///
    /// **CENTRED, and that is not a preference.** `SchematicCanvas`
    /// ends in `.frame(maxWidth: .infinity)` with no alignment
    /// because a schematic is a standalone illustration — its own
    /// docstring rules that, against the left-aligned treatment a
    /// preview beside its controls gets. So the canvas centres the
    /// mini-screen inside whatever cell it is given, and a
    /// leading-aligned label under it lands at the CELL's edge
    /// rather than the picture's: the glyph hung ~14 pt left of
    /// the frame it was labelling (owner eye-confirm, 2026-08-17).
    /// Centring the stack is what `LayoutStrip` does with the same
    /// pair, and it is the only arrangement that survives the
    /// canvas being greedy.
    ///
    /// Nothing here overrides accessibility. `SchematicCanvas`
    /// gives the drawing its own label, and naming this stack
    /// would REPLACE that label with a bare mode name — the
    /// failure `AppRulesCensusRenderTests` records for menus, in a
    /// different costume.
    private func tile(
        _ slot: PresetPreviewPlan.Slot
    ) -> some View {
        VStack(spacing: 4) {
            LayoutSchematicView(
                mode: slot.mode,
                settings: layout.settings,
                windows: LayoutSchematic.defaultWindowCount,
                scale: .tile
            )
            Label(
                slot.mode.displayName,
                systemImage: slot.mode.glyph
            )
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(SettingsTheme.ink2)
        }
    }

    /// One dismissal, reachable three ways.
    ///
    /// A read-only sheet has no second answer, so Return and Escape
    /// must both mean the same thing as the button. `.defaultAction`
    /// alone left Escape dead (architect review, 2026-08-17), and a
    /// modal surface a keyboard user cannot back out of is the
    /// "usable without a mouse" claim failing in its plainest form.
    /// `.onExitCommand` rather than a second `.keyboardShortcut`,
    /// because a `Button` may carry only one and Return is the one
    /// worth having on the button itself.
    private var footer: some View {
        HStack {
            Spacer()
            Button(doneLabel, action: onDone)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .kiwiProminentButton()
        }
        .frame(maxWidth: .infinity)
        .padding(Self.pad)
    }

    private var doneLabel: String {
        L("presets.layouts.done", "Done")
    }
}
