import KiwiDeskCore
import SwiftUI

extension SettingsView {
    /// The pushed area's pane. Split out of `SettingsView` when
    /// the shell's theme wiring took that file past the §2.1
    /// ceiling — pure routing, and the one place the twelve areas
    /// are named, so it is the part that reads best alone.
    ///
    /// Takes the destination rather than reading `selection`: that
    /// property is `private`, and an extension in a second file
    /// cannot see it. Passing it also makes the pane a function of
    /// its argument, which is what it always was.
    @ViewBuilder func detail(
        _ selection: SettingsDestination?
    ) -> some View {
        switch selection {
        // nil is Home, which mounts instead of this pane —
        // unreachable here, but the switch must be total.
        case nil:
            EmptyView()
        case .spaces:
            SpacesSection(model: model)
        case .layoutDefaults:
            LayoutDefaultsSection(model: model)
        case .monitors:
            MonitorsSection(model: model)
        case .colors:
            ColorsMotionSection(model: model)
        case .advancedColors:
            AdvancedColorsSection(model: model)
        case .gapsAndBorders:
            GapsAndBordersSection(model: model)
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

    @ViewBuilder var detailPane: some View {
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
                detail(model.destination)
                    // The in-area half of the flip's reflow
                    // (#760): Home's grid animates its own, and
                    // an area the user is standing in animates
                    // the surfaces the flip inserts (the
                    // drawer, the Layers card, the per-row
                    // offers) the same 0.3 s instead of popping
                    // them in — one mount for all ten panes,
                    // keyed on the mode so nothing else rides
                    // it. Reduce Motion stands down; the wash
                    // and frame still answer.
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(
                                duration: SettingsReveal.scroll
                            ),
                        value: model.settingsMode
                    )
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
    func reveal(
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
        let destination = model.destination
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
                model.destination == destination
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
