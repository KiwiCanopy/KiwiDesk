import KiwiDeskCore
import SwiftUI

/// The shell's chrome — the one header bar, the two banners,
/// the content, and the save surface in whichever form the
/// measured band gives it (#678 turn 9, responsive since 17a).
/// Split from `SettingsView` at the §2.1 ceiling; what stays
/// there is the shell's routing and its state.
extension SettingsView {

    /// Banner + footer wrapper shared by both modes, so the
    /// profile banner and three-verb footer stay put whether the
    /// raw Lua editor or the structured detail is showing.
    @ViewBuilder func chrome(
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
