import KiwiDeskCore
import SwiftUI

/// Mouse & trackpad ▸ On the KiwiShelf (#1726). Each entry greys
/// on its own `GestureSurface`; the reason for every off surface is
/// said once, at the group's foot, outside every grey — grey,
/// don't hide, and a dim is not a sentence. The Spring delay is
/// read and linked, never copied: its control is the Space Bar's.
struct GesturesShelfEntries: View {
    @ObservedObject var model: SettingsModel

    private var settings: TilingSettings { model.config.settings }

    var body: some View {
        GestureEntry(
            L(
                "shortcuts.gestures.drop_on_space",
                "Drag a window onto a Space on the KiwiShelf to "
                    + "move it there."
            ),
            surface: .spaceBar,
            settings: settings,
            pace: .story
        ) { GesturePicture.DropOnSpace(t: $0) }
        GestureRule()
        GestureEntry(
            springText,
            surface: .spaceBar,
            settings: settings,
            pace: .story
        ) {
            GesturePicture.Spring(t: $0)
        } control: {
            link(Self.springLinkProse)
        }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.glyph_click",
                "Click an app icon to go to its Space and focus it. "
                    + "An app with several windows there opens a "
                    + "menu of them."
            ),
            surface: .spaceBar,
            settings: settings,
            pace: .steps
        ) { GesturePicture.GlyphClick(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.overflow_menu",
                "Click +n for a menu of the windows it hides. "
                    + "Nothing switches until you pick one."
            ),
            surface: .spaceBar,
            settings: settings,
            pace: .steps
        ) { GesturePicture.OverflowMenu(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.glyph_hover",
                "Point at an app icon to see the app and the "
                    + "titles of its windows."
            ),
            surface: .spaceBar,
            settings: settings,
            pace: .steps
        ) { GesturePicture.GlyphHover(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.shelf_scroll",
                "Scroll over the KiwiShelf to see the Spaces or "
                    + "windows that run past its edge."
            ),
            surface: .shelf,
            settings: settings
        ) { GesturePicture.ShelfScroll(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.app_bar",
                "Drag an item along the App Bar to reorder its "
                    + "windows."
            ),
            surface: .appBar,
            settings: settings,
            pace: .steps
        ) { GesturePicture.AppBarReorder(t: $0) }
        GestureRule()
        GestureEntry(
            L(
                "shortcuts.gestures.app_bar_hover",
                "Point at an App Bar item whose title is cut short "
                    + "to see it in full."
            ),
            surface: .appBar,
            settings: settings,
            pace: .steps
        ) { GesturePicture.AppBarHover(t: $0) }
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

    /// The delay read from the draft, so the sentence says what
    /// this profile does, in the diff readout's own seconds form.
    private var springText: String {
        L(
            "shortcuts.gestures.spring",
            "Keep holding it over the Space and, after %1$@, the "
                + "view opens that Space with the window already "
                + "in its layout.",
            SettingsValueReadout.spaceBarSeconds(
                settings.spaceBarStyle.springDelay
            )
        )
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
