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

    /// Only `+n` mixes apps, so only its headers carry icons.
    var showsIcons: Bool {
        if case .overflow = self { return true }
        return false
    }
}

/// What a peek shows (#1946, the owner's ruling): one group per
/// app, its header above its windows, every window a row — an
/// untitled one named as the glyph menu names it (#1947).
struct BarPeekContent: Equatable {
    struct Group: Equatable {
        let app: String
        /// The app's icon, on `+n` only, where the rows mix apps.
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

    /// Groups `rows` by app in first-seen order, every row kept.
    @MainActor
    init(rows: [SpaceBarWindowMenu.Row], icons: Bool) {
        var order: [String] = []
        var titles: [String: [String]] = [:]
        var firstIcon: [String: NSImage?] = [:]
        for row in rows {
            if titles[row.app] == nil {
                order.append(row.app)
                firstIcon[row.app] = row.icon
            }
            titles[row.app, default: []].append(
                SpaceBarWindowMenu.windowName(row.title)
            )
        }
        groups = order.map { app in
            Group(
                app: app,
                icon: icons ? firstIcon[app] ?? nil : nil,
                titles: titles[app] ?? []
            )
        }
    }
}
