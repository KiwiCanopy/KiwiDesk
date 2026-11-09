import Foundation

/// Which modifier taps the keyboard tap holds while an own floating
/// panel is key (#1229): every tap and tap leader, save under
/// KiwiHub a tap bound to one of its own sides, which runs that
/// side's toggle as its chord does. Derived from the own key window
/// alone, never from a flag a panel sets.
enum ModifierTapHold: Equatable, Sendable {
    /// No own floating panel is key: every tap fires.
    case none
    /// KiwiHub is key: only a row bound to a KiwiHub side fires.
    case kiwiHub
    /// Another own floating panel is key, a bar's grown peek among
    /// them: nothing fires.
    case all

    init(_ reading: OwnKeyWindowReading?) {
        guard let reading, reading.floatsOverWindows else {
            self = .none
            return
        }
        self = reading.isKiwiHub ? .kiwiHub : .all
    }

    /// Whether `row` fires under this hold. A tap leader is never
    /// bound to a side, so it is held under either.
    func lets(_ row: ModifierTapRow) -> Bool {
        switch self {
        case .none: true
        case .kiwiHub: row.opensKiwiHubSide
        case .all: false
        }
    }
}
