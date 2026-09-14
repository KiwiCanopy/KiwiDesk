import KiwiDeskCore

/// The Mac Checklist's sentences (#1365). Each caption is ONE
/// frame whose link sits at `CrossReferenceRow.linkSlot` — the
/// System Settings path on a settings row, the KiwiDesk surface
/// on a habit — so a locale places the link where its word order
/// wants; a name the app already labels is interpolated from its
/// key, never retyped (#818) — spelled inline at each site, since
/// the `InterpolatedLabelTests` scan cannot follow a helper.
@MainActor
enum MacChecklistText {
    /// The one path every row shares — all six live in Desktop &
    /// Dock, and the sub-pane anchors are undocumented.
    static var pathLabel: String {
        L(
            "mac_checklist.path.desktop_dock",
            "System Settings ▸ Desktop & Dock"
        )
    }

    static var provenance: String {
        L(
            "mac_checklist.provenance",
            "Read from macOS whenever this window comes forward; "
                + "KiwiDesk changes none of them."
        )
    }

    /// Caption for a settings row, the path at the slot.
    static func caption(for key: MacChecklistKey) -> String {
        let slot = CrossReferenceRow.linkSlot
        switch key {
        case .rearrangeSpaces:
            return L(
                "mac_checklist.rearrange_spaces.caption",
                "macOS reorders your Desktops by use, so the Desktop "
                    + "a profile is bound to is never where you left "
                    + "it. %1$@",
                slot
            )
        case .switchOnActivate:
            return L(
                "mac_checklist.switch_on_activate.caption",
                "Activating an app would jump you to another "
                    + "Desktop; with KiwiDesk you go there on purpose, "
                    + "with %1$@ or a Desktop shortcut. %2$@",
                L("shortcuts.app_behavior.open_or_focus", "Open or Focus"),
                slot
            )
        case .stageManager:
            return L(
                "mac_checklist.stage_manager.caption",
                "Two window managers would arrange the same "
                    + "windows. %1$@",
                slot
            )
        case .edgeTiling:
            return L(
                "mac_checklist.edge_tiling.caption",
                "Two tilers would answer one drag. %1$@",
                slot
            )
        case .clickWallpaper:
            return L(
                "mac_checklist.click_wallpaper.caption",
                "With gaps between windows, a click that lands on "
                    + "the wallpaper sweeps every window aside. %1$@",
                slot
            )
        case .doubleClickTitle:
            return L(
                "mac_checklist.double_click_title.caption",
                "KiwiDesk snaps a zoomed window back into its slot, "
                    + "so a double-click costs you only the round "
                    + "trip — None spares you that. %1$@",
                slot
            )
        case .habitHide, .habitBigWindows, .habitKeyboard,
            .habitFloat, .habitDock, .selfTicks:
            return ""
        }
    }

    /// A habit's sentence; where it names a KiwiDesk surface the
    /// destination sits at `CrossReferenceRow.linkSlot`.
    /// `panelChord` is the shortcuts panel's LIVE chord glyphs
    /// (`ShortcutsOpenBinding.comboGlyphs`), nil where nothing is
    /// bound — a second key rather than an empty argument.
    static func habit(
        for key: MacChecklistKey,
        panelChord: String? = nil
    ) -> String {
        let slot = CrossReferenceRow.linkSlot
        switch key {
        case .habitHide:
            return L(
                "mac_checklist.habit.hide.caption",
                "Hiding (⌘H, ⌘M, the yellow light) takes "
                    + "a window out of the tiling and out of macOS\u{2019}s "
                    + "own bookkeeping. Keep what you\u{2019}ll reuse open "
                    + "on another Space — switch there, or pull it "
                    + "over with %1$@ — and close only what "
                    + "you\u{2019}re done with: ⌘W closes the "
                    + "window, ⌘Q quits the app (the red light and "
                    + "Dock ▸ right-click ▸ Quit do the same).",
                L("shortcuts.app_behavior.open_or_focus", "Open or Focus")
            )
        case .habitBigWindows:
            return L(
                "mac_checklist.habit.big_windows.caption",
                "%1$@ shows one window at full size and %2$@ gives "
                    + "each window as much width as you want — set "
                    + "a Space to either in %3$@. The green button works "
                    + "too, but it opens a macOS Space of its own, "
                    + "outside your KiwiDesk Spaces.",
                L("layout.monocle.name", "Monocle"),
                L("layout.scrolling.name", "Scrolling"),
                slot
            )
        case .habitKeyboard:
            guard let panelChord else {
                return L(
                    "mac_checklist.habit.keyboard.caption",
                    "The focus and move chords beat any drag; the "
                        + "mouse is for content. They are all in %1$@.",
                    slot
                )
            }
            return L(
                "mac_checklist.habit.keyboard.caption_panel",
                "The focus and move chords beat any drag; the mouse "
                    + "is for content. They are all in %1$@ — or press "
                    + "%2$@ to see them over whatever you are doing.",
                slot,
                panelChord
            )
        case .habitFloat:
            return L(
                "mac_checklist.habit.float.caption",
                "A calculator, a color picker, a chat popover: one "
                    + "rule in %1$@ and it stops competing for a slot.",
                slot
            )
        case .habitDock:
            return L(
                "mac_checklist.habit.dock.caption",
                "With the %1$@ on, the Dock only takes up room on "
                    + "the screen — auto-hide it in %3$@ and launch by "
                    + "Spotlight or %2$@.",
                L("bars.switch.space_bar", "Space Bar"),
                L("shortcuts.app_behavior.open_or_focus", "Open or Focus"),
                slot
            )
        case .rearrangeSpaces, .switchOnActivate, .stageManager,
            .edgeTiling, .clickWallpaper, .doubleClickTitle,
            .selfTicks:
            return ""
        }
    }

    /// The section header's readout, the count last so no locale
    /// has to agree with it — and the all-done frame countless,
    /// since `total` is the census's and a form chosen for 4 is
    /// wrong the day a fifth essential joins.
    static func progress(done: Int, total: Int) -> String {
        guard done < total else {
            return L("mac_checklist.progress.all", "All done")
        }
        return L(
            "mac_checklist.progress",
            "Done: %1$d of %2$d",
            done,
            total
        )
    }

    /// The Home card's subtitle.
    static func cardProgress(done: Int, total: Int) -> String {
        guard done < total else {
            return L(
                "home.card.mac_checklist.all",
                "All essentials done"
            )
        }
        return L(
            "home.card.mac_checklist.subtitle",
            "Essentials done: %1$d of %2$d",
            done,
            total
        )
    }

    /// The fallback row's caption: macOS would not answer, so the
    /// tick is the user's — never a false "Not yet".
    static var unreadable: String {
        L(
            "mac_checklist.unreadable",
            "KiwiDesk couldn\u{2019}t read this one — tick it "
                + "once you\u{2019}ve set it. %1$@",
            CrossReferenceRow.linkSlot
        )
    }
}
