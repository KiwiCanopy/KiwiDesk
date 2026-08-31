import CoreGraphics
import KiwiDeskCore

/// State needed to render the quick menu's Layout submenu (#752).
/// Layout belongs to the space showing on each screen.
struct LayoutMenuInfo {
    /// One connected screen and the layout of the space showing on it.
    struct Screen {
        let space: SpaceID
        /// The screen's own name (`Display.name`) — the row label.
        let name: String
        /// Display identity used as ordering tie-breaker.
        let id: DisplayID
        /// Display frame origin for ordering (`DeskOrder`).
        let origin: CGPoint
        let mode: LayoutMode?
        /// Saved layout mode from active profile, if known.
        let savedMode: LayoutMode?

        var hasDrifted: Bool {
            LayoutMenuInfo.drifted(live: mode, saved: savedMode)
        }
    }

    /// Focused space layout mode and profile saved state.
    let activeMode: LayoutMode?
    let activeProfileName: String?
    let savedModeForActiveSpace: LayoutMode?
    /// Every connected screen, in provider discovery order.
    let screens: [Screen]

    /// Returns true if live layout mode differs from a known saved mode.
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

    /// Whether ANY screen's shown space stands on a temporary
    /// layout. The keep row's enablement (#1179 condition 1):
    /// the verb writes the whole profile, so arming it on the
    /// FOCUSED screen alone left a non-focused screen's submenu
    /// saying "not saved to profile" above a greyed row that
    /// would have saved it.
    var anyScreenHasDrifted: Bool {
        activeSpaceHasDrifted
            || screens.contains(where: \.hasDrifted)
    }

    /// Screens in desk reading order via `DeskOrder` (#752).
    var orderedScreens: [Screen] {
        screens.sorted {
            DeskOrder.key(origin: $0.origin, id: $0.id)
                < DeskOrder.key(origin: $1.origin, id: $1.id)
        }
    }

    /// Whether multi-display nesting applies (> 1 screen).
    var nestsPerScreen: Bool { screens.count > 1 }

    /// Empty initial layout menu state.
    static let empty = LayoutMenuInfo(
        activeMode: nil,
        activeProfileName: nil,
        savedModeForActiveSpace: nil,
        screens: []
    )
}

/// Applied target for a selected Layout menu item.
struct LayoutMenuTarget {
    let mode: LayoutMode
    let scope: Scope

    /// Which space (or spaces) the row sets.
    enum Scope {
        /// The focused space.
        case activeSpace
        /// The space showing on one screen.
        case space(SpaceID)
        /// Every screen's shown space at menu build time.
        case everyScreen(asBuilt: [SpaceID])
    }
}
