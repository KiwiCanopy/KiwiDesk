import KiwiDeskCore
import SwiftUI

/// Mouse & Trackpad ▸ On the KiwiShelf (#1726). The Spring delay is
/// read and linked, never copied: its control is the Space Bar's.
struct GesturesShelfEntries: View {
    @ObservedObject var model: SettingsModel

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        GestureEntry(
            .dropOnSpace,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.dropOnSpace)
        GestureRule()
        GestureEntry(
            .spring,
            settings: settings,
            gestures: model.config.scrollGesture
        ) {
            link(Self.springLinkProse)
        }
        .gestureAnchored(.spring)
        GestureRule()
        GestureEntry(
            .glyphClick,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.glyphClick)
        GestureRule()
        GestureEntry(
            .glyphPeek,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.glyphPeek)
        GestureRule()
        GestureEntry(
            .shelfScroll,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.shelfScroll)
        GestureRule()
        GestureEntry(
            .contextMenu,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.contextMenu)
        GestureRule()
        GestureEntry(
            .appBarReorder,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.appBarReorder)
        GestureRule()
        GestureEntry(
            .appBarHover,
            settings: settings,
            gestures: model.config.scrollGesture
        )
        .gestureAnchored(.appBarHover)
    }

    /// Every pointer to KiwiShelf & Bars this group draws.
    private func link(_ prose: String) -> some View {
        CrossReferenceRow(
            prose: prose,
            linkTitle: SettingsDestination.bars.title,
            destination: .bars
        )
        .font(.caption)
    }

    static var springLinkProse: String {
        L(
            "shortcuts.gestures.spring_link",
            "Change the wait in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }
}
