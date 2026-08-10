import KiwiDeskCore
import SwiftUI

/// Which destinations offer the live-preview panel (#678
/// redesign spec). DATA, not a scattered condition: the
/// two-column mount, the pill's centring offset and the tests
/// all consult this one set, and a pass that teaches a new
/// area to preview (the keyboard, pass 5) joins by adding its
/// case here and its content below. An area with nothing to
/// show hides the panel and takes the full width — the
/// prototype's own rule, so absence is a stated verdict, not
/// a missing feature.
enum SettingsDetailPanelOffer {
    /// v1 (owner-scoped 2026-08-09): the four areas whose
    /// preview renderers exist this pass. Shortcuts joined in
    /// pass 5 (the keyboard board), which is the extension motion
    /// #793-#795 each repeat.
    static let offering: Set<SettingsDestination> = [
        .gapsAndBorders, .bars, .colors, .layoutDefaults,
        .shortcuts,
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
/// being the in-area one (#678 redesign spec). The spec's `›`
/// collapse handle is deliberately NOT built (owner
/// 2026-08-10): the planned responsive pass will drop the
/// panel by WIDTH below 1200 pt, and a manual collapse beside
/// that is a persisted preference duplicating what the window
/// already decides.
struct SettingsDetailPanel: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination

    var body: some View {
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
        case .shortcuts:
            KeyboardPreviewPanel(model: model)
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
        // One rows array feeds the heading's N, the list and
        // the elsewhere remainder — the counts a user can
        // cross-check against a visible list must BE that
        // list's count (owner 2026-08-10: `draftChangeCount`
        // said "1" over a three-row per-space family).
        let all = SettingsDiffRowSource.rows(for: model)
        let rows = SettingsDiffRowSource.areaRows(
            all,
            in: destination
        )
        return VStack(alignment: .leading, spacing: 12) {
            SettingsTheme.hairline.frame(height: 1)
            Text(
                L(
                    "panel.changed_in_draft",
                    "Changed in this draft — %1$d",
                    rows.count
                )
            )
            .font(
                .system(size: 10, weight: .semibold)
                    .monospaced()
            )
            .kerning(1.4)
            .textCase(.uppercase)
            .foregroundStyle(SettingsTheme.ink3)
            if !rows.isEmpty {
                SettingsDiffRowsView(rows: rows) { row in
                    jump(to: row)
                }
            } else if all.isEmpty {
                Text(
                    L(
                        "panel.draft_clean",
                        "Everything matches the saved profile."
                    )
                )
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
            } else {
                Text(
                    L(
                        "panel.draft_clean_area",
                        "No changes in this area — %1$d "
                            + "elsewhere in the draft.",
                        all.count
                    )
                )
                .font(.callout)
                .foregroundStyle(SettingsTheme.ink3)
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

    /// The panel's slice of the draft: only rows whose census
    /// placement lands in `destination` — the whole draft
    /// lives in the save pill's popover, and a row the user
    /// cannot see change on this screen is noise (owner
    /// 2026-08-10). Same area mapping as the row's own jump.
    /// Stated residue: a row whose key has no Settings surface
    /// (nil placement area — a Lua-only override) appears only
    /// in the pill's popover.
    static func areaRows(
        _ rows: [SettingsDiffRow],
        in destination: SettingsDestination
    ) -> [SettingsDiffRow] {
        rows.filter { row in
            guard let area = row.key.placement.area else {
                return false
            }
            return SettingsDestination(area: area) == destination
        }
    }
}
