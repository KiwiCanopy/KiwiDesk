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
    /// The in-flight scroll+flash choreography, held so a second
    /// search click supersedes the first instead of overlapping.
    @State private var revealTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// The sidebar selection lives on the model, not in `@State`
    /// — see `SettingsModel.destination`. A locale change re-keys
    /// this view, and `@State` would not survive it.
    private var selection: SettingsDestination {
        get { model.destination }
        nonmutating set { model.destination = newValue }
    }

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
        // The one discard dialog (#515). Hosted HERE, above the
        // `editingLua` branch, not inside `chrome` — `chrome` is
        // instantiated in both arms, and two of the gated actions
        // flip `editingLua`, so a dialog hosted there would be
        // torn down by its own confirm button. This `Group`'s
        // identity is stable across that flip, and it still
        // covers both modes (the raw editor's "Back to visual
        // editor" needs the gate as much as the shell does).
        .discardConfirmation(model: model)
        .onChange(of: model.editingStoredProfile) { _, editing in
            // The selection must never point at a destination
            // the sidebar just hid (#18).
            if !selection.isReachable(
                editingStoredProfile: editing
            ) {
                selection = .spaces
            }
        }
        // A navigation request — the #326 "Edit in Settings…"
        // deep link, or a #277 search hit. Guarded by the same
        // reachability filter as every other nav path (#18).
        .onChange(of: model.pendingReveal) { _, request in
            apply(request)
        }
        .onAppear { apply(model.pendingReveal) }
    }

    /// Applies a request's destination and surface — the half
    /// that is meaningful in both modes.
    ///
    /// Deliberately does NOT clear the request when it succeeds:
    /// the detail pane's scroll driver owns the reveal and the
    /// clear, so a request landing while the raw Lua editor shows
    /// survives until there is a pane with something to scroll.
    /// An *unreachable* one is cleared here, since no pane will
    /// ever consume it.
    private func apply(_ request: SettingsAnchor?) {
        guard let request else { return }
        guard
            request.destination.isReachable(
                editingStoredProfile: model.editingStoredProfile
            )
        else {
            model.pendingReveal = nil
            return
        }
        selection = request.destination
        switch request.surface {
        case .main:
            break
        case .layoutMode(let mode):
            model.layoutModeTab = mode
        case .bar(let editor):
            model.barEditor = editor
        }
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
                selection: $model.destination,
                editingStoredProfile: model.editingStoredProfile,
                spotlightProfiles:
                    model.profileSummaries.isEmpty,
                reveal: { model.pendingReveal = $0 }
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
            // ONE reader for all ten sections (#277), above the
            // `switch` rather than wrapped around each section's
            // own `ScrollView`: the proxy scrolls any scroll view
            // in its subtree that holds the id, so ten per-section
            // wrappers would buy nothing and drift.
            ScrollViewReader { proxy in
                detail
                    .environment(\.settingsFlash, model.flash)
                    .onChange(of: model.pendingReveal) {
                        _,
                        request in
                        reveal(request, proxy: proxy)
                    }
                    .onAppear {
                        reveal(model.pendingReveal, proxy: proxy)
                    }
            }
        }
    }

    /// Scrolls to a request's anchor and flashes it, then clears
    /// the request. Runs after `apply` has already selected the
    /// destination and surface.
    private func reveal(
        _ request: SettingsAnchor?,
        proxy: ScrollViewProxy
    ) {
        guard let request else { return }
        model.pendingReveal = nil
        guard let anchor = request.anchor else { return }
        revealTask?.cancel()
        revealTask = Task { @MainActor in
            // Yield one pass first: `apply` may have just flipped
            // the surface that *creates* the target view, and
            // asking the proxy for an id in the same synchronous
            // pass as the state change that mints it misses.
            await Task.yield()
            let scroll = { proxy.scrollTo(anchor, anchor: .top) }
            if reduceMotion {
                scroll()
            } else {
                withAnimation(
                    .easeInOut(duration: SettingsReveal.scroll)
                ) { scroll() }
            }
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.scroll + SettingsReveal.settle
                )
            )
            guard !Task.isCancelled else { return }
            model.flash(anchor)
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
