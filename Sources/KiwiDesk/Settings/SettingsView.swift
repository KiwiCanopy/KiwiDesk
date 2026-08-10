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
    /// The detached preview card's per-mount answer, and `nil`
    /// while the band's own default stands (17a): `.medium`
    /// floats it open, the narrower bands wait behind "Show
    /// preview". Deliberately NOT persisted — the panel is
    /// dropped by WIDTH, and a stored open/closed flag beside
    /// that is a preference duplicating what the window already
    /// decides (`DetailPanelTests`). Cleared on every
    /// destination change, so an area starts at its band's
    /// default rather than inheriting the last area's answer.
    @State var previewShown: Bool?
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
    /// Whether the current destination HAS a panel at all — the
    /// capability, not the layout. Every responsive verdict
    /// below is this AND a width question, so an area outside
    /// the offer set can never reach one.
    var panelOffered: Bool {
        SettingsDetailPanelOffer.offers(model.destination)
            && !model.editingLua
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
        // The one measurement (17a). Everything that yields as
        // the window narrows — the panel's column, the row axis,
        // the save pill's kind, the header's search field —
        // derives from the class this hands down, so no site
        // compares a width of its own. `HomeScreen` reads its
        // own geometry for the column COUNT below the cap, which
        // is the one measurement that is not a band question.
        GeometryReader { geo in
            let width = SettingsWidthClass.of(
                width: geo.size.width
            )
            shell(width)
                .environment(\.settingsWidth, width)
                // Widening back into the docked band retires
                // the card's per-mount answer. Without this a
                // card closed at 1100 stays closed on the way
                // back DOWN from 1400 — the user's "not now"
                // outliving the band it was given in, which is
                // the persisted-collapse behaviour this pass
                // refused to build (architecture review,
                // 2026-08-11).
                .onChange(of: width) { _, now in
                    if now.docksPanel { previewShown = nil }
                }
        }
        // The digest's hard minimum (17a): below 720 the window
        // stops resizing — the tiled Settings window must
        // survive whatever slot the layout gives it. The old
        // 840 paid for the floating sidebar card, which is gone.
        .frame(
            minWidth: SettingsWidthClass.minimum,
            minHeight: 540
        )
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
        // A new area starts at its band's preview default: the
        // card the user closed in Bars says nothing about
        // whether they want one in Shortcuts.
        .onChange(of: model.destination) { _, _ in
            previewShown = nil
        }
    }

    /// The window's two shells, both under the same chrome and
    /// both taking the measured band.
    @ViewBuilder private func shell(
        _ width: SettingsWidthClass
    ) -> some View {
        if model.editingLua {
            chrome(width) { LuaEditorTab(model: model) }
        } else {
            structuredShell(width)
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
    private func structuredShell(
        _ width: SettingsWidthClass
    ) -> some View {
        chrome(width) {
            if selection == nil {
                HomeScreen(model: model)
            } else {
                detailPane(width)
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
        _ width: SettingsWidthClass,
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
            // The one-line mode-switch confirmation (#678 4c):
            // a search pick into a Power-User-only area flips
            // the mode silently (`ensureModeAdmits`), and this
            // line is the only place that says so. Transient —
            // the model clears it itself.
            if let notice = model.searchModeNotice {
                SettingsSearchNotice(text: notice)
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
            // The offer to summon the detached preview. Below
            // the card's own overlay because it exists only
            // when the card does not — they are never both on
            // screen, so their order is free.
            .overlay(alignment: .bottomTrailing) {
                showPreviewOffer(width)
            }
            // The save pill floats OVER the content instead of
            // docking below it (#678 turn 9; owner 2026-08-09
            // overturned the docked-footer ruling). An overlay
            // never reserves layout space, so the content keeps
            // the full height while the pill exists only when
            // the draft does. Bottom-centred on the CONTENT
            // column; `detailPane` offsets it past the preview
            // panel when one is docked.
            //
            // Below the row breakpoint it stops floating and
            // becomes the sibling bar below — see the branch
            // after this stack. The overlay is EMPTY there
            // rather than conditionally applied, so the content
            // subtree's identity survives the crossing.
            .overlay(alignment: .bottom) {
                if !width.docksSavePill {
                    SettingsFooter(model: model)
                        .padding(.bottom, 22)
                        // Centred on the CONTENT column: half
                        // the panel's width, the prototype's
                        // own `calc(50% - 196px)`.
                        .offset(
                            x: panelDocked(width)
                                ? -SettingsTheme.panelWidth / 2
                                : 0
                        )
                }
            }
            // The detached card goes on LAST, and the order is
            // the whole point: `.overlay` composes outward, so
            // whatever is applied last paints and hit-tests
            // above everything before it. Mounted before the
            // pill — as it was first written — a card dragged
            // low is covered by the pill, and its grab bar
            // loses clicks to a control it is sitting on top
            // of (code review, 2026-08-11).
            .overlay(alignment: .topTrailing) {
                detachedPreview(width)
            }
            // "Same content, same three verbs, different
            // physics" (17a): at this width a floating pill
            // sits on top of the rows it is about, so it docks
            // into a real footer bar — a SIBLING, which reserves
            // its own height, rather than an overlay. The one
            // component in the shell that changes kind.
            if width.docksSavePill {
                SettingsFooter(model: model, docked: true)
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
