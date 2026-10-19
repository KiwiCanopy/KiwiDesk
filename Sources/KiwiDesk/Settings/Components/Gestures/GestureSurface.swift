import KiwiDeskCore

/// Where a Mouse & trackpad gesture happens (#1726). Every entry
/// names one — a required argument. No surface greys for a bar's
/// visibility: a hidden bar's shortcut shows it, and the gesture
/// then acts on it (#761).
enum GestureSurface: CaseIterable {
    /// Any window: always available.
    case windows
    /// The Space Bar's items.
    case spaceBar
    /// A layout's App Bar.
    case appBar
    /// The KiwiShelf as a whole — either bar.
    case shelf
}
