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
        /// One per window shown, in row order; never empty.
        let titles: [String]
        /// Every window the group stands for, shown or not.
        let windowCount: Int

        /// The header's count pill: from two windows, as a bare
        /// number, so it needs no localized frame.
        var count: Int? {
            windowCount >= BarPeekContent.countFloor ? windowCount : nil
        }
    }

    /// The fewest windows a header counts (owner ruling).
    static let countFloor = 2

    let groups: [Group]

    /// Every window the peek stands for.
    var windowCount: Int { groups.reduce(0) { $0 + $1.windowCount } }

    private init(groups: [Group]) { self.groups = groups }

    /// `count` windows in order — the first, or the last
    /// `fromEnd` — each group keeping the count it stands for; a
    /// group left with none is dropped.
    func keeping(_ count: Int, fromEnd: Bool = false) -> BarPeekContent {
        var left = count
        var kept: [Group] = []
        for group in fromEnd ? groups.reversed() : groups where left > 0 {
            let titles =
                fromEnd
                ? Array(group.titles.suffix(left))
                : Array(group.titles.prefix(left))
            left -= titles.count
            kept.append(
                Group(
                    app: group.app,
                    icon: group.icon,
                    titles: titles,
                    windowCount: group.windowCount
                )
            )
        }
        return BarPeekContent(groups: fromEnd ? kept.reversed() : kept)
    }

    /// Groups `rows` per app NAME in first-seen order, every row
    /// kept — the key the bars group by, so a glyph standing for
    /// sibling processes of one app (#1785) is one group. Icons mark
    /// the groups only where the rows mix apps — `+n`, or any list
    /// that does.
    @MainActor
    init(rows: [BarWindowRow]) {
        var order: [BarWindowRow] = []
        var titles: [String: [String]] = [:]
        for row in rows {
            if titles[row.app] == nil { order.append(row) }
            titles[row.app, default: []].append(
                SpaceBarWindowMenu.windowName(row.title)
            )
        }
        let mixed = order.count > 1
        groups = order.map { first in
            let all = titles[first.app] ?? []
            return Group(
                app: first.app,
                icon: mixed ? first.icon : nil,
                titles: all,
                windowCount: all.count
            )
        }
    }
}
