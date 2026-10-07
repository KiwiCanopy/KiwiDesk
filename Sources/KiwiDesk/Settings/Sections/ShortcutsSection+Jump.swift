import KiwiDeskCore
import SwiftUI

/// The pinned jump bar's wiring (#1520): the chips read the
/// page's geometry, and a click puts the group's header under the
/// bar — Mouse & trackpad opening its card on the way.
extension ShortcutsSection {
    func jumpBar(_ proxy: ScrollViewProxy) -> some View {
        ShortcutsJumpBar(
            marked: jumpReading.marked,
            underlapped: jumpReading.underlapped,
            readout: editingReadout(ShortcutsJumpBar.shownName(selected)),
            spokenReadout: editingReadout(selected)
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

    /// Re-renders the bar only when its reading changed.
    func show(_ reading: ShortcutsJumpReading) {
        if reading != jumpReading { jumpReading = reading }
    }

    private func jump(
        to group: ShortcutsJumpGroup,
        proxy: ScrollViewProxy
    ) {
        show(jumpTracker.jump(to: group))
        if group == .gestures { gesturesExpanded = true }
        withAnimation(
            reduceMotion
                ? nil
                : .easeInOut(duration: SettingsReveal.scroll)
        ) {
            proxy.scrollTo(group.control.id, anchor: .top)
        }
    }
}
