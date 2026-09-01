import KiwiDeskCore
import SwiftUI

extension SettingsView {
    /// Renders the section pane for `selection`.
    @ViewBuilder func detail(
        _ selection: SettingsDestination?
    ) -> some View {
        switch selection {
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

    /// Two-column detail hosting content and docked preview panel (17a).
    @ViewBuilder func detailPane(
        _ width: SettingsWidthClass
    ) -> some View {
        HStack(spacing: 0) {
            contentColumn
            // `panelDocked` FIRST — the same predicate the pill's
            // centring offset reads: a conjunct added there must
            // move the pill and the mount together (review
            // 2026-08-10; the two had already drifted once).
            if panelDocked(width),
                let destination = model.destination
            {
                SettingsTheme.hairline.frame(width: 1)
                SettingsDetailPanel(
                    model: model,
                    destination: destination
                )
            }
        }
    }

    @ViewBuilder private var contentColumn: some View {
        VStack(spacing: 0) {
            if model.hasCustomLua {
                CustomLuaBanner()
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                Divider()
                    .padding(.top, 10)
            }
            // Single reader across all sections (#277).
            ScrollViewReader { proxy in
                // Hoisted so the label cannot resolve empty: this
                // is now the arrival focus stop (#996), and a
                // nameless one is worse than the presses it saves.
                if let destination = model.destination {
                    detail(destination)
                        // Every section's root is a scroll view,
                        // which VoiceOver lands on as a bare
                        // "scroll area" (owner, #812 session 2) —
                        // the area's title names it.
                        .accessibilityLabel(destination.title)
                        .frame(
                            maxWidth: SettingsTheme.contentMaxWidth
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .center
                        )
                        // AFTER the frames, never before: drawn
                        // round the pre-layout content, the ring
                        // loses its leading edge to the centring
                        // that follows (owner, 2026-09-01). The
                        // shape is stated too — a full-bleed
                        // rectangle reads as damage rather than
                        // as focus. Shrinking what is focusable
                        // is the sanctioned answer where hiding
                        // the ring is not (design-decisions ▸ a
                        // focus ring is the platform's).
                        .contentShape(
                            .focusEffect,
                            RoundedRectangle(
                                cornerRadius:
                                    SettingsTheme.cardRadius,
                                style: .continuous
                            )
                        )
                        .focusable()
                        .focused($contentFocused)
                        // A click must not ring the pane, and
                        // the wiring is spelled HERE because a
                        // modifier handed the binding never
                        // fires (owner eye-confirm, 2026-09-01).
                        .onChange(of: contentFocused) { _, now in
                            guard now, ClickBornFocus.isClickBorn
                            else { return }
                            contentFocused = false
                        }
                        // LAST, so the ring sits inside it. Pad
                        // before `.focusable()` and the padded —
                        // larger — view is the one focused, which
                        // puts the ring on the window's own edges
                        // where both sides are clipped away
                        // (owner, 2026-09-01).
                        .padding(SettingsMetrics.focusRingInset)
                        // Animated surface reflow on mode switch (#760).
                        .animation(
                            reduceMotion
                                ? nil
                                : .easeOut(
                                    duration: SettingsReveal.scroll
                                ),
                            value: model.settingsMode
                        )
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
    }

    /// Scrolls pane to `anchor` and triggers highlight flash.
    func reveal(
        _ anchor: String?,
        proxy: ScrollViewProxy
    ) {
        guard let anchor else { return }
        model.nav.pendingScroll = nil
        revealTask?.cancel()
        // Captured, so a task that outlives its pane bails —
        // cross-destination duplicate labels are legitimate and
        // unguarded; this stale window is the one place they
        // would bite.
        let destination = model.destination
        revealTask = Task { @MainActor in
            await Task.yield()
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: SettingsReveal.scroll)
            ) { proxy.scrollTo(anchor, anchor: .top) }
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.scroll + SettingsReveal.settle
                )
            )
            guard
                !Task.isCancelled,
                model.destination == destination
            else { return }
            // Re-issue, un-animated: one yield drains main-actor
            // work but does not promise SwiftUI has LAID OUT the
            // new subtree, so the first scrollTo can be a silent
            // no-op — and the wash would paint off-screen.
            proxy.scrollTo(anchor, anchor: .top)
            let token = model.nav.startFlash(anchor)
            // Under Reduce Motion, hold absorbs fade duration.
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.hold
                        + (reduceMotion ? SettingsReveal.fade : 0)
                )
            )
            model.nav.endFlash(token: token)
        }
    }
}
