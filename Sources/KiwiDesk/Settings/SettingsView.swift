import KiwiDeskCore
import SwiftUI

/// The dashboard shell (#68 §3.1): the profile/state banner as
/// the window header, a two-group sidebar (This Profile /
/// Whole App), the selected section as the detail pane — or the
/// raw Lua editor when the file holds foreign code — and the
/// stable three-verb save footer (§3.12).
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// Profiles is the natural entry point for both the
    /// first-run and the returning user (§5.8) — it is the
    /// default selection, not the top row.
    @State private var selection: SettingsDestination =
        .profiles

    var body: some View {
        VStack(spacing: 0) {
            ProfileSyncBanner(model: model)
            Divider()
            content
            Divider()
            SettingsFooter(model: model)
        }
        .frame(minWidth: 760, minHeight: 540)
        .onChange(of: model.editingStoredProfile) { _, editing in
            // The selection must never point at a destination
            // the sidebar just hid (#18).
            if editing,
                !selection.visibleWhileEditingStoredProfile
            {
                selection = .spaces
            }
        }
    }

    @ViewBuilder private var content: some View {
        if model.editingLua {
            LuaEditorTab(model: model)
        } else {
            NavigationSplitView {
                SettingsSidebar(
                    selection: $selection,
                    editingStoredProfile:
                        model.editingStoredProfile
                )
            } detail: {
                detailPane
            }
        }
    }

    @ViewBuilder private var detailPane: some View {
        VStack(spacing: 0) {
            if model.hasCustomLua {
                CustomLuaBanner()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                Divider()
                    .padding(.top, 10)
            }
            detail
        }
    }

    @ViewBuilder private var detail: some View {
        switch selection {
        case .spaces:
            SpacesSection(model: model)
        case .layoutDefaults:
            LayoutDefaultsSection(model: model)
        case .monitors:
            MonitorsSection(model: model)
        case .appearance:
            AppearanceSection(model: model)
        case .behavior:
            BehaviorSection(model: model)
        case .profiles:
            ProfilesSection(model: model)
        case .shortcuts:
            ShortcutsSection(model: model)
        case .appRules:
            AppRulesSection(model: model)
        case .general:
            GeneralSection(model: model)
        }
    }
}
