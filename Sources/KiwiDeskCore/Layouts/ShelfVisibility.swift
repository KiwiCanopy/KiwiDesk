import Foundation

/// Whether a bar stays on screen (#761): `always`; `auto`, which
/// hides it to a mark the pointer reveals; or `hidden`, which
/// draws nothing and reserves nothing until the bar's shortcut
/// shows it over the windows. Each bar stores its own — the App
/// Bar one per layout that can carry it — and two bars on one
/// edge resolve through `TilingSettings.barEdges(space:app:)`:
/// the edge reserves for its most present bar.
public enum ShelfVisibility: String, Sendable, Codable, CaseIterable {
    case always
    case auto
    case hidden

    /// How present the value keeps a bar at rest — `always` most,
    /// `hidden` least; an edge reads its members' highest.
    var presence: Int {
        switch self {
        case .always: 2
        case .auto: 1
        case .hidden: 0
        }
    }

    /// Whether the bar's shortcut can show it (#761): every value
    /// but `always`, which is already shown.
    public var revealable: Bool { self != .always }
}

/// Which bar a shelf question names (#761).
public enum ShelfBar: Sendable, Hashable {
    case space
    case app
}
