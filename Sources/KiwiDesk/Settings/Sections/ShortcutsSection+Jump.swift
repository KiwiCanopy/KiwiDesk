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
            readout: editingReadout
        ) { group in
            jump(to: group, proxy: proxy)
        }
    }

    /// Names the edited layer once there is a choice — the one
    /// `layersExist` reading, asked rather than counted (#1127).
    private var editingReadout: String? {
        guard ShortcutsGates(config: model.config).layersExist else {
            return nil
        }
        return L(
            "shortcuts.editing_layer",
            "Editing the \u{201C}%1$@\u{201D} layer",
            selected
        )
    }

    private func jump(
        to group: ShortcutsJumpGroup,
        proxy: ScrollViewProxy
    ) {
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
