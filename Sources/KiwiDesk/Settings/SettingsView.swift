import KiwiDeskCore
import SwiftUI

/// The dashboard shell (#68 §3.1): a full-height, two-group
/// source list (This Profile / Whole App), and a detail column
/// that carries the profile/state banner on top, the selected
/// section (or the raw Lua editor when the file holds foreign
/// code) in the middle, and the stable three-verb save footer
/// (§3.12) at the bottom.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// Profiles is the natural entry point for both the
    /// first-run and the returning user (§5.8) — it is the
    /// default selection, not the top row.
    @State private var selection: SettingsDestination =
        .profiles

    var body: some View {
        Group {
            if model.editingLua {
                chrome { LuaEditorTab(model: model) }
            } else {
                structuredShell
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .onChange(of: model.editingStoredProfile) { _, editing in
            // The selection must never point at a destination
            // the sidebar just hid (#18).
            if !selection.isReachable(
                editingStoredProfile: editing
            ) {
                selection = .spaces
            }
        }
    }

    /// The structured settings shell: a non-collapsible source
    /// list, and a detail column that carries the full-width
    /// header bar (section title + profile dropdown + status),
    /// the scrolling section content, and the save footer. The
    /// split view's auto collapse toggle is removed (#68 — a
    /// nine-row taxonomy never needs to hide).
    private var structuredShell: some View {
        NavigationSplitView {
            SettingsSidebar(
                selection: $selection,
                editingStoredProfile: model.editingStoredProfile
            )
            // Applied to the sidebar column's content (not the
            // split view) so it actually drops the auto toggle.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            chrome { detailPane }
        }
        .environment(\.settingsNavigate) { destination in
            // Third #18 enforcement point beside the sidebar's
            // offer filter and the onChange repair above: links
            // must refuse what the sidebar hides (the repair
            // only fires on editing-flag transitions, not
            // selection).
            guard
                destination.isReachable(
                    editingStoredProfile:
                        model.editingStoredProfile
                )
            else { return }
            selection = destination
        }
    }

    /// Banner + footer wrapper shared by both modes, so the
    /// profile banner and three-verb footer stay put whether the
    /// raw Lua editor or the structured detail is showing.
    @ViewBuilder private func chrome(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            ProfileHeaderBar(
                model: model,
                title: selection.title,
                showsProfileContext: selection.showsProfileContext
            )
            // `content()` stacks on top of the resign-on-click
            // background (#93): SwiftUI hit-tests top-down, so
            // any real control inside `content()` still claims
            // the click first — only genuinely empty area falls
            // through to the background tap.
            ZStack {
                ClickAwayResignsFocus()
                content()
            }
            Divider()
            SettingsFooter(model: model)
        }
        // Pull the detail up under the (empty) unified toolbar
        // so the header bar sits flush at the top — no empty
        // toolbar strip above it — while the sidebar keeps the
        // traffic lights over its full height.
        .ignoresSafeArea(.container, edges: .top)
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
