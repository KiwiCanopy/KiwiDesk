import KiwiDeskCore
import SwiftUI

/// Destinations supporting the side live-preview panel (#678).
/// DATA, not a scattered condition: the two-column mount, the
/// pill's centring offset and the tests all consult this one set.
/// An area with nothing to show hides the panel and takes the
/// full width — absence is a stated verdict. General is
/// deliberately NOT here (#795, owner 2026-08-16): its diff list
/// would be a structural zero. Advanced Colours joined in #793;
/// the extension motion is a case here plus a branch below.
enum SettingsDetailPanelOffer {
    static let offering: Set<SettingsDestination> = [
        .gapsAndBorders, .bars, .colors, .layoutDefaults,
        .shortcuts, .advancedColors, .spaces,
    ]

    static func offers(
        _ destination: SettingsDestination?
    ) -> Bool {
        guard let destination else { return false }
        return offering.contains(destination)
    }
}

/// Right-column panel displaying live preview and draft change list
/// (#678, 17a, owner ruling 2026-08-10).
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
            // VoiceOver lands on the scroll view as a bare
            // "scroll area" before interacting into it (owner,
            // #812 session 2); the header sentence names what the
            // reader is about to enter.
            .accessibilityLabel(headerSentence)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .frame(
            width: SettingsTheme.panelWidth,
            alignment: .topLeading
        )
        .background(SettingsTheme.panel)
    }

    private var headerSentence: String {
        L(
            "panel.live_preview",
            "Live preview · %1$@",
            destination.title
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(headerSentence)
                .font(
                    .system(size: 10, weight: .semibold)
                        .monospaced()
                )
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(SettingsTheme.ink3)
                .accessibilityAddTraits(.isHeader)
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
        case .advancedColors:
            AdvancedColorsPanel(model: model)
        case .spaces:
            SpacesPanelPreview(model: model)
        case .shortcuts:
            KeyboardPreviewPanel(model: model)
        case .layoutDefaults:
            LayoutPreviewPanel(
                model: model,
                mode: model.nav.layoutModeTab ?? .bsp
            )
        default:
            // Unreachable while the mount consults
            // `SettingsDetailPanelOffer` — the guard suite pins
            // that every offering destination has a branch here.
            EmptyView()
        }
    }

    private var diffList: some View {
        // One rows array feeds the heading's N, the list and the
        // elsewhere remainder — a count a user can cross-check
        // against a visible list must BE that list's count (owner
        // 2026-08-10: `draftChangeCount` said "1" over a
        // three-row family).
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
            .accessibilityAddTraits(.isHeader)
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

    /// Jumps to setting control associated with diff row
    /// (`SettingsView.apply`).
    private func jump(to row: SettingsDiffRow) {
        guard let anchor = SettingsDiffJump.anchor(for: row)
        else { return }
        model.nav.pendingReveal = anchor
    }

}

/// Builds display rows for uncommitted draft changes.
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
        // Drift the header claims but no config leaf carries
        // (#1197) — ONE list, so the footer's N is still the
        // count of the list it opens.
        rows += driftRows(for: model)
        return rows
    }

    /// Filters draft diff rows relevant to specific destination area
    /// (owner ruling 2026-08-10).
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
