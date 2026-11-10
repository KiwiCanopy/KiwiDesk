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
            readout: editingReadout(ShortcutsJumpBar.shownName(selected)),
            spokenReadout: editingReadout(selected),
            groups: ShortcutsJumpGroup.shown(
                desktopsDrawn: MacOSDesktopsGroup.hasRows(expander)
            )
        ) { group in
            jump(to: group, proxy: proxy)
        }
    }

    /// Names the edited layer once there is a choice — the one
    /// `layersExist` reading, asked rather than counted (#1127).
    /// Drawn with the name cut to fit, spoken with it whole.
    private func editingReadout(_ name: String) -> String? {
        guard ShortcutsGates(config: model.config).layersExist else {
            return nil
        }
        return L(
            "shortcuts.editing_layer",
            "Editing the \u{201C}%1$@\u{201D} layer",
            name
        )
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
        let owner = ShortcutsPagePart.owner(
            of: target,
            expander: expander,
            bindings: model.shortcutsLayerBindings
        )
        if owner == nil { buildsWholePage = true }
        let shown = segment
        let switches = owner.map { !$0.segments.contains(shown) } ?? false
        if let owner, switches {
            model.nav.shortcutsSegment = owner.segment(from: shown)
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
