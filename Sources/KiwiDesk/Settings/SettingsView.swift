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
    @State private var revealTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
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
            // The footer's overline. A token rule rather than a
            // `Divider()`: the shell's three horizontal rules
            // (header underline, this, the card borders) are one
            // colour in the prototype, and `Divider` renders a
            // system separator that tracks neither.
            SettingsTheme.hairline.frame(height: 1)
            SettingsFooter(model: model)
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
                detail(selection)
                    // The panes' top gutter, spent here rather
                    // than as padding inside each one: a content
                    // margin moves what "top of the viewport"
                    // means, so `scrollTo(anchor: .top)` lands a
                    // revealed card with the same gutter above it
                    // that a pane's first card has at rest —
                    // where padding would only have pushed the
                    // resting content down and left the scrolled
                    // card just as flush.
                    //
                    // One call site, not ten: the margin
                    // propagates to every scroll view below,
                    // which is the same reach the one
                    // `ScrollViewReader` above already relies on.
                    .contentMargins(
                        .top,
                        SettingsMetrics.paneInset,
                        for: .scrollContent
                    )
                    .environment(\.settingsFlash, model.nav.flash)
                    .environment(
                        \.settingsRevealTarget,
                        model.nav.revealTarget
                    )
                    .onChange(of: model.nav.pendingScroll) {
                        _,
                        anchor in
                        reveal(anchor, proxy: proxy)
                    }
                    .onAppear {
                        reveal(
                            model.nav.pendingScroll,
                            proxy: proxy
                        )
                    }
            }
        }
    }

    /// Phase 2: scrolls the pane to `anchor` and flashes it, then
    /// clears the request. Runs after `apply` has selected the
    /// destination and surface, so the target exists or is about
    /// to.
    private func reveal(
        _ anchor: String?,
        proxy: ScrollViewProxy
    ) {
        guard let anchor else { return }
        model.nav.pendingScroll = nil
        revealTask?.cancel()
        // Captured, so a task that outlives its pane bails instead
        // of relying on the id being absent from the new one.
        // Cross-destination duplicate labels are legitimate (only
        // one destination mounts), and nothing guards them — this
        // stale window is the single place where that would bite.
        let destination = selection
        revealTask = Task { @MainActor in
            // Yield one pass first: `apply` may have just flipped
            // the surface that *creates* the target view, and
            // asking the proxy for an id in the same synchronous
            // pass as the state change that mints it misses.
            await Task.yield()
            if reduceMotion {
                proxy.scrollTo(anchor, anchor: .top)
            } else {
                withAnimation(
                    .easeInOut(duration: SettingsReveal.scroll)
                ) { proxy.scrollTo(anchor, anchor: .top) }
            }
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.scroll + SettingsReveal.settle
                )
            )
            guard
                !Task.isCancelled,
                selection == destination
            else { return }
            // Re-issue, un-animated. One cooperative yield drains
            // queued main-actor work but does not promise SwiftUI
            // has LAID OUT the new subtree, so the first
            // `scrollTo` can be a silent no-op — and then the wash
            // would paint off-screen and the user would see
            // nothing at all. Layout has certainly run by now; if
            // the first attempt landed, this is a no-op.
            proxy.scrollTo(anchor, anchor: .top)
            let token = model.nav.startFlash(anchor)
            // Under Reduce Motion the wash has no fade to live
            // through — clearing removes it instantly — so the
            // hold absorbs the fade's duration instead. Without
            // this the accessibility branch gets a 0.3 s cue
            // against everyone else's 1.2 s, which is backwards.
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.hold
                        + (reduceMotion ? SettingsReveal.fade : 0)
                )
            )
            // Clearing is what triggers the fade — the modifier
            // keeps no timer of its own.
            model.nav.endFlash(token: token)
        }
    }

}
