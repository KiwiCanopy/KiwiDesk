import KiwiDeskCore
import SwiftUI

/// The pinned jump bar's wiring (#1520): the chips read the
/// page's geometry, and a click puts the group's header under the
/// bar. Built-in alone draws it (#3184).
extension ShortcutsSection {
    func jumpBar(
        _ proxy: ScrollViewProxy,
        expander: ShortcutsFamilyRows
    ) -> some View {
        ShortcutsJumpBar(
            tracker: jumpTracker,
            groups: ShortcutsJumpGroup.shown(
                desktopsDrawn: MacOSDesktopsGroup.hasRows(expander)
            )
        ) { group in
            jump(to: group, proxy: proxy)
        }
    }

    private func jump(
        to group: ShortcutsJumpGroup,
        proxy: ScrollViewProxy
    ) {
        jumpTracker.jump(to: group)
        // The part's id: the lazy stack knows it before the part is
        // built, unlike the card's own (#3060).
        let part = ShortcutsPagePart(group).id
        targetScroll?.cancel()
        targetScroll = Task { @MainActor in
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: SettingsReveal.scroll)
            ) {
                proxy.scrollTo(part, anchor: .top)
            }
            await settleThenReissue { proxy.scrollTo(part, anchor: .top) }
        }
    }

    /// Scrolls to a row the recorder names: to the part of the page
    /// drawing it first, then to its part unless the page holds it
    /// built, then to the row (#3060, #3184).
    func scroll(
        to target: String,
        proxy: ScrollViewProxy,
        expander: ShortcutsFamilyRows
    ) {
        let placed = ShortcutsPagePart.placing(
            target,
            expander: expander,
            bindings: model.shortcutsLayerBindings,
            shown: segment
        )
        let owner = placed?.part
        if owner == nil { buildsWholePage = true }
        let switches = placed.map { $0.segment != segment } ?? false
        if let placed, switches {
            model.nav.shortcutsSegment = placed.segment
        }
        let built =
            !switches
            && (owner.map(model.shortcutsPage.built.contains) ?? false)
        targetScroll?.cancel()
        targetScroll = Task { @MainActor in
            if switches {
                // The other part's stack has to exist first.
                try? await Task.sleep(
                    nanoseconds: SettingsReveal.nanoseconds(
                        SettingsReveal.settle
                    )
                )
                guard !Task.isCancelled else { return }
            }
            if !built {
                if let owner { proxy.scrollTo(owner.id, anchor: .top) }
                // A yield does not promise layout (`SettingsView.reveal`).
                try? await Task.sleep(
                    nanoseconds: SettingsReveal.nanoseconds(
                        SettingsReveal.settle
                    )
                )
                guard !Task.isCancelled else { return }
            }
            withAnimation(reduceMotion ? nil : .default) {
                proxy.scrollTo(target, anchor: .center)
            }
            await settleThenReissue {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    /// Re-issues a scroll un-animated once its animation is over: a
    /// lazy stack lays out the parts between on the way, so the first
    /// landing rests on estimated heights (`SettingsView.reveal`).
    private func settleThenReissue(_ scroll: () -> Void) async {
        try? await Task.sleep(
            nanoseconds: SettingsReveal.nanoseconds(
                SettingsReveal.scroll + SettingsReveal.settle
            )
        )
        guard !Task.isCancelled else { return }
        scroll()
    }

    /// Takes a reveal's request to build every part (#3060).
    func takeWholePageRequest() {
        guard model.nav.shortcutsWholePage else { return }
        model.nav.shortcutsWholePage = false
        buildsWholePage = true
    }
}
