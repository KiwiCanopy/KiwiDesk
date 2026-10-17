import KiwiDeskCore

extension GestureItem {
    /// The entry's sentence — the card's, and the strip's tooltip
    /// (#1726, owner ruling 2026-10-17). The Spring delay is read
    /// from the draft, in the diff readout's own seconds form.
    @MainActor func sentence(_ settings: TilingSettings) -> String {
        switch self {
        case .scrollStep:
            return L(
                "shortcuts.gestures.scroll.sentence",
                "Hold these keys and scroll to move focus window by "
                    + "window along a %1$@ row. On any other Space, "
                    + "focus moves through its windows in order "
                    + "instead.",
                L("layout.scrolling.name", "Scrolling")
            )
        case .spaceStep:
            return L(
                "shortcuts.gestures.scroll.space_step_sentence",
                "Hold these keys and scroll to switch to the next or "
                    + "previous Space on the screen under the "
                    + "pointer, one per swipe or wheel notch."
            )
        case .hoverFocus:
            return L(
                "shortcuts.gestures.hover_focus",
                "Rest the pointer on a window to focus it and bring "
                    + "it to the front."
            )
        case .followFocus:
            return L(
                "shortcuts.gestures.follow_focus",
                "Focus moves with a shortcut, a Space switch, "
                    + "switching apps or a closed window."
            )
        case .swap:
            return L(
                "shortcuts.gestures.swap",
                "Drag a window onto another to swap them, or onto "
                    + "another screen to move it there."
            )
        case .edge:
            return L(
                "shortcuts.gestures.edge",
                "Drag a window's edge to resize it."
            )
        case .dropOnSpace:
            return L(
                "shortcuts.gestures.drop_on_space",
                "Drag a window onto a Space on the KiwiShelf to "
                    + "move it there."
            )
        case .spring:
            return L(
                "shortcuts.gestures.spring",
                "Keep holding it over the Space and, after %1$@, the "
                    + "view opens that Space with the window already "
                    + "in its layout.",
                SettingsValueReadout.spaceBarSeconds(
                    settings.spaceBarStyle.springDelay
                )
            )
        case .glyphClick:
            return L(
                "shortcuts.gestures.glyph_click",
                "Click an app icon to go to its Space and focus it."
            )
        case .glyphPeek:
            return L(
                "shortcuts.gestures.glyph_peek",
                "Point at an app icon or +n to see its windows; click "
                    + "one to go to it. Nothing switches until you do."
            )
        case .shelfScroll:
            return L(
                "shortcuts.gestures.shelf_scroll",
                "Scroll over the KiwiShelf to see the Spaces or "
                    + "windows that run past its edge."
            )
        case .contextMenu:
            return L(
                "shortcuts.gestures.context_menu",
                "Right-click the KiwiShelf for a menu of what you "
                    + "clicked: a Space's layout and how many glyphs "
                    + "it shows, what to do with a window or its app, "
                    + "and the KiwiShelf's settings."
            )
        case .appBarReorder:
            return L(
                "shortcuts.gestures.app_bar",
                "Drag an item along the App Bar to reorder its "
                    + "windows."
            )
        case .appBarHover:
            return L(
                "shortcuts.gestures.app_bar_hover",
                "Point at an App Bar item whose title is cut short "
                    + "to see it in full."
            )
        }
    }
}
