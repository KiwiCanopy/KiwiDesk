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
        // 840, not 760: the floating sidebar card (#297) costs
        // ~16pt of column width in insets, so the old minimum
        // squeezed the detail pane (settled by eye).
        .frame(minWidth: 840, minHeight: 540)
        .onChange(of: model.editingStoredProfile) { _, editing in
            // The selection must never point at a destination
            // the sidebar just hid (#18).
            if !selection.isReachable(
                editingStoredProfile: editing
            ) {
                selection = .spaces
            }
        }
        // A deep-link request (#326 "Edit in Settings…") navigates
        // the sidebar, then clears so it fires once. Guarded by the
        // same reachability filter as every other nav path (#18).
        .onChange(of: model.pendingDestination) { _, destination in
            consume(destination)
        }
        .onAppear { consume(model.pendingDestination) }
    }

    private func consume(_ destination: SettingsDestination?) {
        guard let destination else { return }
        if destination.isReachable(
            editingStoredProfile: model.editingStoredProfile
        ) {
            selection = destination
        }
        model.pendingDestination = nil
    }

    /// The structured settings shell: a fixed-width source list
    /// and a detail column that carries the full-width header
    /// bar (section title + profile dropdown + status), the
    /// scrolling section content, and the save footer.
    ///
    /// A plain `HStack`, deliberately not `NavigationSplitView`
    /// (#297): on macOS 26 the split view's divider cannot be
    /// locked — `navigationSplitViewColumnWidth(min:ideal:max:)`
    /// is ignored, `NSSplitViewItem` thickness writes are
    /// reverted by the private controller on the next layout,
    /// and replacing its delegate crashes. A static column is
    /// non-resizable and non-collapsible by construction — the
    /// System Settings behavior #68 wanted when it removed the
    /// collapse toggle (a nine-row taxonomy never needs to
    /// hide).
    private var structuredShell: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selection: $selection,
                editingStoredProfile: model.editingStoredProfile,
                spotlightProfiles:
                    model.profileSummaries.isEmpty
            )
            chrome { detailPane }
                .frame(maxWidth: .infinity)
        }
        // Both columns own the titlebar region themselves: the
        // sidebar card floats up under the traffic lights (the
        // System Settings look), the detail header sits flush at
        // the top. Ignored here at the shell — a child's own
        // `ignoresSafeArea` cannot reach past the stack cell.
        .ignoresSafeArea(.container, edges: .top)
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
            // Paused-permission banner outranks the per-section
            // Lua banner: it renders in the shared chrome (every
            // section *and* the raw Lua editor), because missing
            // Accessibility makes the whole dashboard inert, not
            // just one tab. Gated here (not self-gating) so the
            // padding never reserves empty space when trusted.
            if model.permissionPaused {
                PermissionPausedBanner(
                    onResolve: model.onResolvePermission
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
            }
            // `ClickAwayResignsFocus` installs a window-scoped
            // mouse-down monitor (#93) that commits an edited
            // field when the click lands outside it. It's a
            // zero-size, hit-test-transparent probe, so the ZStack
            // order is incidental — it never intercepts clicks.
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
        // The one discard dialog (#515), hosted here because
        // this wrapper is shared by the structured shell AND
        // the raw Lua editor — "Back to visual editor" discards
        // unsaved Lua and needs the same gate.
        .discardConfirmation(model: model)
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
        case .bars:
            BarsSection(model: model)
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
