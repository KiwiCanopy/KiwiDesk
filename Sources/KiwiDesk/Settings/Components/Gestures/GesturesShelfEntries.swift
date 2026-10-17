import KiwiDeskCore
import SwiftUI

/// Mouse & trackpad ▸ On the KiwiShelf (#1726). Each entry greys
/// on its own `GestureSurface`; the reason for every off surface is
/// said once, at the group's foot, outside every grey — grey,
/// don't hide, and a dim is not a sentence. The Spring delay is
/// read and linked, never copied: its control is the Space Bar's.
struct GesturesShelfEntries: View {
    @ObservedObject var model: SettingsModel
    /// The entry that plays once as it appears (`GesturesDrawer`).
    @Binding var playing: GestureItem?

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        GestureEntry(
            .dropOnSpace,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.dropOnSpace)
        GestureRule()
        GestureEntry(
            .spring,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        ) {
            link(Self.springLinkProse)
        }
        .gestureAnchored(.spring)
        GestureRule()
        GestureEntry(
            .glyphClick,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.glyphClick)
        GestureRule()
        GestureEntry(
            .glyphPeek,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.glyphPeek)
        GestureRule()
        GestureEntry(
            .shelfScroll,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.shelfScroll)
        GestureRule()
        GestureEntry(
            .contextMenu,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.contextMenu)
        GestureRule()
        GestureEntry(
            .appBarReorder,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.appBarReorder)
        GestureRule()
        GestureEntry(
            .appBarHover,
            settings: settings,
            gestures: model.config.scrollGesture,
            playing: $playing
        )
        .gestureAnchored(.appBarHover)
        ForEach(offReasons, id: \.self) { prose in
            link(prose)
        }
    }

    /// One sentence per surface that is off, in declaration order.
    private var offReasons: [String] {
        GestureSurface.allCases.compactMap { surface in
            surface.isOff(settings) ? surface.offProse : nil
        }
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
