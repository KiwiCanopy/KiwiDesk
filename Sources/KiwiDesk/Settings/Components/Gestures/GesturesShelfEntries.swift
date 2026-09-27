import KiwiDeskCore
import SwiftUI

/// Mouse & trackpad ▸ On the KiwiShelf (#1726). An entry whose bar
/// is off greys and says where it turns on — grey, don't hide —
/// its pointer kept out of the grey so the link still works. The
/// Spring delay is linked and its value read, never copied.
struct GesturesShelfEntries: View {
    @ObservedObject var model: SettingsModel

    private var settings: TilingSettings { model.config.settings }
    private var spaceBarOn: Bool { settings.spaceBarStyle.enabled }

    var body: some View {
        spaceEntries
        offNote(shown: !spaceBarOn, prose: Self.spaceBarOffProse)
        GestureEntry(
            L(
                "shortcuts.gestures.shelf_scroll",
                "Scroll over the KiwiShelf to see the Spaces or "
                    + "windows that run past its edge."
            )
        ) { GesturePicture.ShelfScroll(t: $0) }
        .modifier(GreyOut(active: !settings.shelfShows))
        GestureEntry(
            L(
                "shortcuts.gestures.app_bar",
                "Drag an item along the App Bar to reorder its "
                    + "windows."
            )
        ) { GesturePicture.AppBarReorder(t: $0) }
        .modifier(GreyOut(active: !settings.anyAppBarCanShow))
        offNote(
            shown: !settings.anyAppBarCanShow,
            prose: Self.appBarOffProse
        )
    }

    @ViewBuilder private var spaceEntries: some View {
        Group {
            GestureEntry(
                L(
                    "shortcuts.gestures.drop_on_space",
                    "Drag a window onto a Space on the KiwiShelf "
                        + "to move it there."
                )
            ) { GesturePicture.DropOnSpace(t: $0) }
            GestureEntry(springText) {
                GesturePicture.Spring(t: $0)
            }
        }
        .modifier(GreyOut(active: !spaceBarOn))
    }

    /// The Spring delay read from the draft, so the sentence says
    /// what this profile does (the control is the Space Bar's).
    private var springText: String {
        L(
            "shortcuts.gestures.spring",
            "Keep holding it over the Space and, after %1$@, the "
                + "view opens that Space with the window already "
                + "in its layout.",
            springDelay
        )
    }

    /// The delay as a value, in the diff readout's seconds form.
    private var springDelay: String {
        let seconds = Double(settings.spaceBarStyle.springDelay) / 1000
        return L(
            "diff.value.seconds",
            "%1$@ s",
            String(format: "%.1f", seconds)
        )
    }

    @ViewBuilder private func offNote(
        shown: Bool,
        prose: String
    ) -> some View {
        if shown {
            CrossReferenceRow(
                prose: prose,
                linkTitle: SettingsDestination.bars.title,
                destination: .bars
            )
            .font(.caption)
        }
    }

    static var spaceBarOffProse: String {
        L(
            "shortcuts.gestures.space_bar_off",
            "The Space Bar is off. Turn it on in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }

    static var appBarOffProse: String {
        L(
            "shortcuts.gestures.app_bar_off",
            "No layout shows an App Bar. Turn one on in %1$@.",
            CrossReferenceRow.linkSlot
        )
    }
}
