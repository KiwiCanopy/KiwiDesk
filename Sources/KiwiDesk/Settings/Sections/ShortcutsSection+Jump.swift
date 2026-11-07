import KiwiDeskCore
import SwiftUI

/// The pinned jump bar's wiring (#1520): the chips read the
/// page's geometry, and a click puts the group's header under the
/// bar — Mouse & trackpad opening its card on the way.
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
        if group == .gestures { gesturesExpanded = true }
        if group == .luaBindings { advancedExpanded = true }
        withAnimation(
            reduceMotion
                ? nil
                : .easeInOut(duration: SettingsReveal.scroll)
        ) {
            // The part's id: the lazy stack knows it before the
            // part is built, unlike the card's own (#3060).
            proxy.scrollTo(ShortcutsPagePart(group).id, anchor: .top)
        }
    }

    /// Scrolls to a row the recorder names: to its part first, so
    /// the lazy stack builds it, then to the row (#3060).
    func scroll(
        to target: String,
        proxy: ScrollViewProxy,
        expander: ShortcutsFamilyRows
    ) {
        let owner = ShortcutsPagePart.owner(of: target, expander: expander)
        if owner == nil { buildsWholePage = true }
        // A part the page has measured is built: no detour.
        let built =
            owner?.group.map {
                jumpTracker.hasMeasured($0.control.id)
            } ?? false
        targetScroll?.cancel()
        targetScroll = Task { @MainActor in
            if let owner, !built {
                proxy.scrollTo(owner.id, anchor: .top)
            }
            // A yield does not promise layout (`SettingsView.reveal`).
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(SettingsReveal.settle)
            )
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .default) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    /// A reveal into a row no part is known to hold builds the whole
    /// page, so the reveal's own scroll finds it (#3060).
    func buildWholePage(revealing target: String?) {
        guard let target,
            ShortcutsPagePart.owner(of: target, expander: expander) == nil
        else { return }
        buildsWholePage = true
    }
}
