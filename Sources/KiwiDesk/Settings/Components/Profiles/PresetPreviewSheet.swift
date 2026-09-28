import KiwiDeskCore
import SwiftUI

/// One request to open the preview sheet via `.sheet(item:)` (#843).
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

/// The preset preview sheet (#859).
///
/// Draws preset layouts using `LayoutSchematic` at `.tile` scale (#753, #862).
/// Rendered from preset's own settings, verified by `PresetPreviewSheetTests`
/// and `DetailPanelTests`.
struct PresetPreviewSheet: View {
    let layout: StandardLayout
    /// Live screen sizes, or nil when opened from other setups drawer.
    let liveSizes: [CGSize]?
    let onDone: () -> Void

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
        .frame(
            minWidth: Self.width(forColumns: Self.columns),
            maxWidth: Self.width(forColumns: Self.columns),
            minHeight: Self.minHeight,
            idealHeight: Self.idealHeight,
            maxHeight: Self.maxHeight
        )
        .background(SettingsTheme.card)
        // Focus-independent Escape handler (`SheetPresentationSeamTests`).
        .background(escapeRoute)
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
                ForEach(Array(group.slots.enumerated()), id: \.element.id) {
                    index,
                    slot in
                    tile(slot, delay: Double(index) * 0.3)
                }
            }
        }
    }

    /// Fixed columns (`Self.columns`) preventing re-wrap across window widths.
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

    /// One space: centered schematic canvas and layout mode name
    /// (`AppRulesCensusRenderTests`). The schematic plays its
    /// layout's story once and on hover (#1750): the sheet is
    /// read, not compared, and nothing in it is edited.
    private func tile(
        _ slot: PresetPreviewPlan.Slot,
        delay: Double
    ) -> some View {
        VStack(spacing: 4) {
            LayoutStoryThumbnail(
                mode: slot.mode,
                settings: layout.settings(sizes: liveSizes),
                scale: .tile,
                delay: delay,
                replaysOnHover: true
            )
            Label(
                slot.mode.displayName,
                systemImage: slot.mode.symbol
            )
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(SettingsTheme.ink2)
        }
    }

    /// Dismissal footer with default action button.
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
        L("common.done", "Done")
    }

    /// Invisible Escape key route carrying `.cancelAction`.
    private var escapeRoute: some View {
        Button(doneLabel, action: onDone)
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
