import KiwiDeskCore
import SwiftUI

/// Which destinations offer the live-preview panel (digest
/// §1.1 / turn 2a). DATA, not a scattered condition: the
/// two-column mount, the pill's centring offset and the tests
/// all consult this one set, and a pass that teaches a new
/// area to preview (the keyboard, pass 5) joins by adding its
/// case here and its content below. An area with nothing to
/// show hides the panel and takes the full width — the
/// prototype's own rule, so absence is a stated verdict, not
/// a missing feature.
enum SettingsDetailPanelOffer {
    /// v1 (owner-scoped 2026-08-09): the four areas whose
    /// preview renderers exist this pass.
    static let offering: Set<SettingsDestination> = [
        .gapsAndBorders, .bars, .colors, .layoutDefaults,
    ]

    static func offers(
        _ destination: SettingsDestination?
    ) -> Bool {
        guard let destination else { return false }
        return offering.contains(destination)
    }
}

/// The detail view's right column: "LIVE PREVIEW · <AREA>",
/// the area's preview drawn from the DRAFT, and the "CHANGED
/// IN THIS DRAFT" diff list — one draft, three views, this
/// being the in-area one (§1.1). Collapsible via the `›`
/// handle; the collapsed strip keeps a `‹` so the panel is
/// one click away, and the pick persists.
struct SettingsDetailPanel: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    @Binding var collapsed: Bool

    var body: some View {
        if collapsed {
            collapsedStrip
        } else {
            expanded
        }
    }

    // MARK: - Expanded

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    preview
                    diffList
                }
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(
            width: SettingsTheme.panelWidth,
            alignment: .topLeading
        )
        .background(SettingsTheme.panel)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(
                L(
                    "panel.live_preview",
                    "Live preview · %1$@",
                    destination.title
                )
            )
            .font(
                .system(size: 10, weight: .semibold)
                    .monospaced()
            )
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(SettingsTheme.ink3)
            Spacer()
            collapseChip(
                glyph: "chevron.right",
                label: L("panel.collapse", "Hide the preview")
            ) {
                collapsed = true
            }
        }
    }

    @ViewBuilder private var preview: some View {
        switch destination {
        case .gapsAndBorders:
            GapsBordersPanelPreview(model: model)
        case .bars:
            BarsPanelPreview(model: model)
        case .colors:
            PaletteScenePanel(model: model)
        case .layoutDefaults:
            // The section's `onAppear` latch writes the tab
            // before first render; `.bsp` only covers the
            // frame between mount and latch.
            LayoutPreviewPanel(
                model: model,
                mode: model.nav.layoutModeTab ?? .bsp
            )
        default:
            // Unreachable while the mount consults
            // `SettingsDetailPanelOffer` — the guard suite pins
            // that every offering destination has a branch
            // here, so a new offer without a preview reds
            // instead of rendering this.
            EmptyView()
        }
    }

    // MARK: - Diff list

    private var diffList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsTheme.hairline.frame(height: 1)
            Text(
                L(
                    "panel.changed_in_draft",
                    "Changed in this draft — %1$d",
                    model.draftChangeCount
                )
            )
            .font(
                .system(size: 10, weight: .semibold)
                    .monospaced()
            )
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(SettingsTheme.ink3)
            if model.draftChangeCount == 0 {
                Text(
                    L(
                        "panel.draft_clean",
                        "Everything matches the saved profile."
                    )
                )
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
            } else {
                SettingsDiffRowsView(
                    rows: SettingsDiffRowSource.rows(for: model)
                ) { row in
                    jump(to: row)
                }
            }
        }
    }

    /// The prototype's "each row is clickable — jumps to the
    /// control that changed": the same anchor pipeline search
    /// lands through (`SettingsView.apply`).
    private func jump(to row: SettingsDiffRow) {
        guard let anchor = SettingsDiffJump.anchor(for: row)
        else { return }
        model.nav.pendingReveal = anchor
    }

    // MARK: - Collapsed

    private var collapsedStrip: some View {
        VStack {
            collapseChip(
                glyph: "chevron.left",
                label: L("panel.expand", "Show the preview")
            ) {
                collapsed = false
            }
            .padding(.top, 18)
            Spacer()
        }
        .frame(width: 36)
        .frame(maxHeight: .infinity)
        .background(SettingsTheme.panel)
    }

    private func collapseChip(
        glyph: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: glyph)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SettingsTheme.ink2)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(SettingsTheme.sunken)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The draft's display rows: every changed setting through the
/// readout, then the two residues the attribution net names —
/// an edited init.lua (one surface, one row) and any
/// unattributed leaf (empty in a healthy diff; shown raw so a
/// hole is at least visible where the guard missed it).
@MainActor
enum SettingsDiffRowSource {
    static func rows(
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        let diff = SettingsDraftDiff.between(
            config: model.config,
            cleanConfig: model.cleanConfig,
            luaSource: model.luaSource,
            cleanLuaSource: model.cleanLuaSource
        )
        var rows: [SettingsDiffRow] = []
        for key in diff.changedSettings {
            rows += SettingsValueReadout.rows(
                for: key,
                old: model.cleanConfig,
                new: model.config
            )
        }
        if diff.luaChanged {
            rows.append(
                SettingsDiffRow.note(
                    .general(.advancedEditLua),
                    label: "init.lua",
                    note: L("diff.note.edited", "Edited")
                )
            )
        }
        for orphan in diff.unattributed {
            rows.append(
                SettingsDiffRow.note(
                    .general(.advancedEditLua),
                    instance: orphan,
                    label: orphan,
                    note: L("diff.note.edited", "Edited")
                )
            )
        }
        return rows
    }
}
