import KiwiDeskCore

/// Where a Mouse & trackpad gesture happens (#1726), and so what
/// must be switched on for it to work. Every entry names one — a
/// required argument — and greys on its surface; the drawer
/// states each off surface's reason once, outside the grey.
enum GestureSurface: CaseIterable {
    /// Any window: always available.
    case windows
    /// The Space Bar's items.
    case spaceBar
    /// A layout's App Bar.
    case appBar
    /// The KiwiShelf as a whole — either bar.
    case shelf

    /// Whether the gesture has nothing to act on. Core's own
    /// predicates, never a re-derivation beside them.
    func isOff(_ settings: TilingSettings) -> Bool {
        switch self {
        case .windows: return false
        case .spaceBar: return !settings.spaceBarStyle.enabled
        case .appBar: return !settings.anyAppBarCanShow
        case .shelf: return !settings.shelfShows
        }
    }

    /// The sentence pointing where the surface turns on, its link
    /// at `CrossReferenceRow.linkSlot`. Nil for a surface that is
    /// never off, and for the shelf, which is off exactly when
    /// both bars are, so their two sentences already say why.
    @MainActor var offProse: String? {
        switch self {
        case .windows, .shelf:
            return nil
        case .spaceBar:
            return L(
                "shortcuts.gestures.space_bar_off",
                "The Space Bar is off. Turn it on in %1$@.",
                CrossReferenceRow.linkSlot
            )
        case .appBar:
            return L(
                "shortcuts.gestures.app_bar_off",
                "No layout shows an App Bar. Turn one on in %1$@.",
                CrossReferenceRow.linkSlot
            )
        }
    }
}
