import AppKit

/// What a hovered bar item asks a peek of (#1946): the windows it
/// stands for and how they read. Core turns it into content when
/// the peek shows, never before.
enum BarPeekSource: Equatable {
    /// A Space Bar app glyph: one app's windows.
    case glyph([WindowID])
    /// A Space Bar `+n` disc: windows of several apps.
    case overflow([WindowID])
    /// An App Bar item that hides text (#1514): its members.
    case appItem([WindowID])

    var windows: [WindowID] {
        switch self {
        case .glyph(let ids), .overflow(let ids), .appItem(let ids):
            ids
        }
    }
}

/// What a peek shows (#1946, the owner's ruling): one group per
/// app, its header above its windows, every window a row — an
/// untitled one named as the glyph menu names it (#1947).
struct BarPeekContent: Equatable {
    struct Group: Equatable {
        let app: String
        /// The app's icon, only where the rows mix apps (`+n`).
        let icon: NSImage?
        /// One per window, in row order; never empty.
        let titles: [String]

        /// The header's count pill: from two windows, as a bare
        /// number, so it needs no localized frame.
        var count: Int? {
            titles.count >= BarPeekContent.countFloor
                ? titles.count : nil
        }
    }

    /// The fewest windows a header counts (owner ruling).
    static let countFloor = 2

    let groups: [Group]

    /// Groups `rows` per app process in first-seen order, every row
    /// kept, the app's name the header. Icons mark the groups only
    /// where the rows mix apps — `+n`, or any list that does.
    @MainActor
    init(rows: [BarWindowRow]) {
        var order: [BarWindowRow] = []
        var titles: [pid_t: [String]] = [:]
        for row in rows {
            if titles[row.pid] == nil { order.append(row) }
            titles[row.pid, default: []].append(
                SpaceBarWindowMenu.windowName(row.title)
            )
        }
        let mixed = order.count > 1
        groups = order.map { first in
            Group(
                app: first.app,
                icon: mixed ? first.icon : nil,
                titles: titles[first.pid] ?? []
            )
        }
    }
}
