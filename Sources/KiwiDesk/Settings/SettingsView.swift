import KiwiDeskCore
import SwiftUI

/// The dashboard shell (#678 turn 9): Home — the card grid that
/// replaced the sidebar — or one pushed area screen, both
/// wrapped in the same chrome: the one header bar, the paused
/// banner, the content, and the stable three-verb save footer
/// (§3.12) at the bottom.
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    /// The in-flight scroll+flash choreography, held so a second
    /// search click supersedes the first instead of overlapping.
    /// Internal like `ensureModeAdmits`, for the same reason: the
    /// detail pane and its reveal driver live in
    /// `SettingsView+Detail` (the §2.1 ceiling split) and `@State`
    /// must be declared here.
    @State var revealTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
    /// The preview panel's collapse pick (digest §1.1) —
    /// remembered like disclosure state, one pick for every
    /// area (the panel is one component that shows different
    /// content, not twelve panels). Internal for the same
    /// §2.1-split reason as `revealTask`: the two-column mount
    /// lives in `SettingsView+Detail`.
    @AppStorage("settings.panel_collapsed")
    var panelCollapsed = false
    /// Whether the current destination is showing an expanded
    /// panel — the pill's centring offset and the two-column
    /// mount both read this, so they cannot disagree.
    var panelExpanded: Bool {
        SettingsDetailPanelOffer.offers(model.destination)
            && !model.editingLua
            && !panelCollapsed
    }
    /// The pushed area lives on the model, not in `@State` —
    /// see `SettingsModel.destination`. A locale change re-keys
    /// this view, and `@State` would not survive it. nil is
    /// Home.
    private var selection: SettingsDestination? {
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
        // The digest's hard minimum (17a): below 720 the window
        // stops resizing — the tiled Settings window must
        // survive whatever slot the layout gives it. The old
        // 840 paid for the floating sidebar card, which is gone.
        .frame(minWidth: 720, minHeight: 540)
        // The window's accent, set ONCE at the root (owner ruled
        // full kiwi over the system accent, 2026-08-04): every
        // toggle, segment and prominent Save below inherits it,
        // so a control cannot opt out by forgetting to. Above the
        // `editingLua` branch for the same reason the discard
        // dialog is — both arms must carry it.
        .tint(SettingsTheme.accent)
        // The one discard dialog (#515). Hosted HERE, above the
        // `editingLua` branch, not inside `chrome` — `chrome` is
        // instantiated in both arms, and two of the gated actions
        // flip `editingLua`, so a dialog hosted there would be
        // torn down by its own confirm button. This `Group`'s
        // identity is stable across that flip, and it still
        // covers both modes (the raw editor's "Back to visual
        // editor" needs the gate as much as the shell does).
        .discardConfirmation(model: model)
        // Two repairs on two different signals, deliberately not
        // merged: reachability genuinely keys on the BOOLEAN — a
        // destination only appears or disappears on the
        // live↔stored transition — while the mode tab keys on the
        // target itself, because stored A → stored B leaves that
        // boolean `true` and is exactly the case that needs it.
        .onChange(of: model.editingStoredProfile) { _, editing in
            // The selection must never point at a destination
            // the grid just hid (#18). Home is the repair
            // target now — it always exists, and it is where
            // the user re-orients.
            if let selection,
                !selection.isReachable(
                    editingStoredProfile: editing
                )
            {
                self.selection = nil
            }
        }
        .onChange(of: model.target) { _, _ in
            // A different profile means a different most-used
            // layout mode, so the mode tab must re-derive (#277).
            model.nav.resetSurfaces()
        }
        // A navigation request — the #326 "Edit in Settings…"
        // deep link, or a #277 search hit. Guarded by the same
        // reachability filter as every other nav path (#18).
        .onChange(of: model.nav.pendingReveal) { _, request in
            apply(request)
        }
        .onAppear { apply(model.nav.pendingReveal) }
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
        chrome {
            if selection == nil {
                HomeScreen(model: model)
            } else {
                detailPane
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        // Escape pops an area back to Home whenever no inner
        // view (a search field, an editor) claimed the key
        // first.
        .onExitCommand {
            if selection != nil { selection = nil }
        }
        .environment(\.settingsNavigate) { destination in
            // Third #18 enforcement point beside the grid's
            // offer filter and the onChange repair above: links
            // must refuse what the grid hides (the repair only
            // fires on editing-flag transitions, not
            // selection).
            guard
                destination.isReachable(
                    editingStoredProfile:
                        model.editingStoredProfile
                )
            else { return }
            // A link into a Power-User-only area switches the mode
            // (4c/4e: a cross-reference must exist in the
            // current mode or offer the switch) — the segment
            // in the header shows the flip.
            ensureModeAdmits(destination)
            selection = destination
        }
    }

    /// Flips Simple → Power User when navigation targets an area the
    /// current mode withholds — search and cross-references
    /// index both modes, so landing must switch rather than
    /// refuse (#678 4c). Internal, not private: the reveal
    /// pipeline (`SettingsView+Reveal.apply`) is the second
    /// caller.
    func ensureModeAdmits(
        _ destination: SettingsDestination
    ) {
        if !HomeCardOrder.isOffered(
            destination,
            mode: model.settingsMode,
            displayCount: model.displays.count,
            editingStoredProfile: model.editingStoredProfile
        ),
            destination.isReachable(
                editingStoredProfile:
                    model.editingStoredProfile
            )
        {
            model.setSettingsMode(.powerUser)
        }
    }

    /// Banner + footer wrapper shared by both modes, so the
    /// profile banner and three-verb footer stay put whether the
    /// raw Lua editor or the structured detail is showing.
    @ViewBuilder private func chrome(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            SettingsHeaderBar(model: model)
                // The header's search results hang BELOW the bar
                // as an overlay (see `HeaderSearch`), and a
                // `VStack` paints its children in order, so
                // without this lift the content below draws over
                // the list. Not cosmetic — it is what makes the
                // results visible at all.
                .zIndex(1)
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
            // Above BOTH panes on purpose: the segment is always
            // in the header, so a flip can wash Home's inserted
            // cards or an in-area surface alike (#760). One
            // mount; the model owns the timeline.
            .environment(
                \.settingsModeReveal,
                model.modeRevealActive
            )
            // The save pill floats OVER the content instead of
            // docking below it (#678 turn 9; owner 2026-08-09
            // overturned the docked-footer ruling). An overlay
            // never reserves layout space, so the content keeps
            // the full height while the pill exists only when
            // the draft does. Bottom-centred on the CONTENT
            // column; `detailPane` offsets it past the preview
            // panel when one is open.
            .overlay(alignment: .bottom) {
                SettingsFooter(model: model)
                    .padding(.bottom, 22)
                    // Centred on the CONTENT column: half the
                    // panel's width, the prototype's own
                    // `calc(50% - 196px)`.
                    .offset(
                        x: panelExpanded
                            ? -SettingsTheme.panelWidth / 2
                            : 0
                    )
            }
        }
        // The page, behind everything. Opaque and flat — the
        // prototype carries no vibrancy, and the header's `.bar`
        // material was what read as a third grey.
        .background(SettingsTheme.page)
        // Pull the detail up under the (empty) unified toolbar
        // so the header bar sits flush at the top — no empty
        // toolbar strip above it — while the sidebar keeps the
        // traffic lights over its full height.
        .ignoresSafeArea(.container, edges: .top)
    }

}
