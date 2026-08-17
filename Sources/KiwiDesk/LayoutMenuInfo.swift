import CoreGraphics
import KiwiDeskCore

/// What the quick menu's Layout submenu needs to draw itself
/// (#752).
///
/// A named struct rather than the anonymous tuple this seam
/// carried until #752: a per-screen list outgrew what a tuple
/// label can explain, and three sites — the controller's default,
/// the `AppDelegate` wiring and the test fake — have to agree on
/// it.
///
/// **The layout belongs to a SPACE, never to a screen.** Each
/// screen simply has one space showing on it
/// (`WorkspaceManager.activeSpace(on:)`, the single truth the
/// tiler lays out per display and the bars read). So a row is
/// *named* for the screen — which is what a user means by "that
/// screen" — while the mode it sets belongs to that screen's
/// space. Getting this backwards is how a per-screen menu grows a
/// per-screen layout setting that does not exist.
struct LayoutMenuInfo {
    /// One connected screen, and what the space showing on it is
    /// running.
    struct Screen {
        let space: SpaceID
        /// The screen's own name (`Display.name`) — the row label.
        let name: String
        /// The screen's identity. Carried as the ordering rule's
        /// final key: two mirrored displays tie on x AND y, and
        /// without it their rows swap between opens.
        let id: DisplayID
        /// The screen's frame origin, carried for ONE reason: it
        /// is the ordering key. See `orderedScreens`.
        let origin: CGPoint
        let mode: LayoutMode?
        /// What the active profile has saved for `space`, or nil
        /// when that is unknown — no profile, or unreadable JSON.
        let savedMode: LayoutMode?

        var hasDrifted: Bool {
            LayoutMenuInfo.drifted(live: mode, saved: savedMode)
        }
    }

    /// The focused space's mode, and what the profile saved for
    /// it.
    ///
    /// Kept alongside `screens` rather than derived from it, and
    /// the reason is not redundancy: these describe the **active**
    /// space, while a `Screen` describes whatever is showing on
    /// one display. They coincide for the focused display and
    /// nowhere else. The flat menu and the save row both speak
    /// about the active space, and `screens` is legitimately
    /// EMPTY while a display change settles
    /// (`allDisplays` is briefly empty — see `KiwiCore+AppBar`),
    /// so a menu built from `screens` alone would lose its
    /// checkmark in exactly that window.
    let activeMode: LayoutMode?
    let activeProfileName: String?
    let savedModeForActiveSpace: LayoutMode?
    /// Every connected screen, in whatever order the provider
    /// gathered them. Read `orderedScreens` to draw.
    let screens: [Screen]

    /// Drift is claimed only when the saved mode is **known**:
    /// nil saved means no profile or unreadable JSON, which is
    /// "unknown" rather than "differs", and claiming drift there
    /// would show a phantom subtitle and enable a save row with
    /// nothing to save.
    ///
    /// One function, two callers — the active space's verdict and
    /// each screen's — because the same rule written twice is the
    /// rule drifting once.
    static func drifted(
        live: LayoutMode?,
        saved: LayoutMode?
    ) -> Bool {
        guard let live, let saved else { return false }
        return live != saved
    }

    var activeSpaceHasDrifted: Bool {
        Self.drifted(
            live: activeMode,
            saved: savedModeForActiveSpace
        )
    }

    /// Screens in desk reading order, through the one rule that
    /// owns it (`DeskOrder`).
    ///
    /// **Sorting is not cosmetic here.**
    /// `WorkspaceManager.allDisplays` is `Array(displays.values)`
    /// — a Dictionary's values, whose order is unspecified and
    /// changes as the dictionary rehashes. Drawn unsorted, the
    /// rows would shuffle between two opens of the same menu with
    /// nothing about the machine having changed.
    ///
    /// An earlier cut sorted `(x, y)` here and claimed to work on
    /// "the same principle the Monitors picture works on". It did
    /// not: `NSScreen` y grows UP, so it listed stacked screens
    /// bottom-to-top — the reverse of Settings ▸ Monitors — and
    /// it carried no identity key, so mirrored displays shuffled
    /// anyway. Routing to `DeskOrder` is what makes the claim
    /// true rather than aspirational.
    var orderedScreens: [Screen] {
        screens.sorted {
            DeskOrder.key(origin: $0.origin, id: $0.id)
                < DeskOrder.key(origin: $1.origin, id: $1.id)
        }
    }

    /// Whether the submenu nests a level deeper.
    ///
    /// One screen keeps exactly the flat menu it has always had:
    /// the extra level buys nothing with one screen and costs a
    /// click on the app's most-used control. Zero screens takes
    /// the same path — that is the display-change window above,
    /// and the flat menu still answers for the active space.
    var nestsPerScreen: Bool { screens.count > 1 }

    /// No core, or nothing to say yet.
    ///
    /// Named `empty` rather than `none`: a static `none` on a
    /// non-optional type reads as `Optional.none` at half its call
    /// sites, and this one is a real value with real fields.
    static let empty = LayoutMenuInfo(
        activeMode: nil,
        activeProfileName: nil,
        savedModeForActiveSpace: nil,
        screens: []
    )
}

/// What picking a Layout row applies.
///
/// Carried in `NSMenuItem.representedObject`, which is `Any?`, so
/// the row's meaning travels with the row instead of being
/// re-derived from its position or its title.
struct LayoutMenuTarget {
    let mode: LayoutMode
    let scope: Scope

    /// Which space (or spaces) the row sets.
    enum Scope {
        /// The focused space — the flat menu's behaviour, and
        /// what `set_mode` does with one argument.
        case activeSpace
        /// The space showing on one screen.
        case space(SpaceID)
        /// Every screen's shown space, in one action — carrying
        /// the spaces the menu was BUILT from, so the apply can
        /// intersect them with what is still connected rather
        /// than trusting either list alone.
        case everyScreen(asBuilt: [SpaceID])
    }
}
