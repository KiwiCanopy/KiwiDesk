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
    /// A collapsed Space chip (#1945): every window its Space holds.
    case space([WindowID])
    /// An overflow mark (#2235): the windows one end of a run
    /// hides, nearest the edge first.
    case run([WindowID])

    var windows: [WindowID] {
        switch self {
        case .glyph(let ids), .overflow(let ids), .appItem(let ids),
            .space(let ids), .run(let ids):
            ids
        }
    }

    /// Whether this is a LIST — an overflow disc or a collapsed
    /// Space, which stand for windows the chip did not draw however
    /// few, or more than one window — the one predicate a glyph's
    /// click, VoiceOver's press and the hold read (#1946). A
    /// one-window glyph or App Bar item is a label: its click
    /// picks, its peek never holds. A collapsed chip is clicked as
    /// a chip, so its list reads at the hold and the check alone
    /// (#1945).
    var isList: Bool {
        switch self {
        case .overflow, .space, .run: true
        case .glyph, .appItem: windows.count > 1
        }
    }

    /// Whether every group wears its app's icon: an overflow mark
    /// draws no glyph beside its peek, so its rows name their apps
    /// even when they are one app (#2235, owner on device).
    var iconsEveryGroup: Bool {
        if case .run = self { return true }
        return false
    }
}

/// What a peek shows (#1946, the owner's ruling): one group per
/// app, its header above its windows, every window a row — an
/// untitled one named as the glyph menu names it (#1947) — and
/// each row its window's button.
struct BarPeekContent: Equatable {
    /// One window's row: the window it picks, its name, and
    /// whether it holds the system focus — its check (#2063).
    struct Row: Equatable {
        let window: WindowID
        let title: String
        var focused = false
    }

    struct Group: Equatable {
        let app: String
        /// The app's icon, only where the rows mix apps (`+n`).
        let icon: NSImage?
        /// One per window shown, in row order.
        let rows: [Row]
        /// Every window the group stands for, shown or not.
        let windowCount: Int

        var titles: [String] { rows.map(\.title) }

    }

    let groups: [Group]
    /// A list's peek reserves the trailing check column on every
    /// row, checked or not, so no title moves with focus (#2063).
    let checks: Bool

    /// The windows shown, top to bottom — the order a glyph's
    /// click cycles in (#2063).
    var order: [WindowID] { groups.flatMap { $0.rows.map(\.window) } }

    /// Every window the peek stands for.
    var windowCount: Int { groups.reduce(0) { $0 + $1.windowCount } }

    private init(groups: [Group], checks: Bool) {
        self.groups = groups
        self.checks = checks
    }

    /// `count` windows in order — the first, or the last
    /// `fromEnd` — each group keeping the count it stands for; a
    /// group left with none is dropped.
    func keeping(_ count: Int, fromEnd: Bool = false) -> BarPeekContent {
        var left = count
        var kept: [Group] = []
        for group in fromEnd ? groups.reversed() : groups where left > 0 {
            let rows =
                fromEnd
                ? Array(group.rows.suffix(left))
                : Array(group.rows.prefix(left))
            left -= rows.count
            kept.append(
                Group(
                    app: group.app,
                    icon: group.icon,
                    rows: rows,
                    windowCount: group.windowCount
                )
            )
        }
        return BarPeekContent(
            groups: fromEnd ? kept.reversed() : kept,
            checks: checks
        )
    }

    /// Groups `rows` per app NAME in first-seen order, every row
    /// kept — a lone window titled as its app included (owner,
    /// #1946) — on the key the bars group by, so a glyph standing
    /// for sibling processes of one app (#1785) is one group. Icons
    /// mark the groups only where the rows mix apps, or always
    /// with `icons` (`BarPeekSource.iconsEveryGroup`). A list
    /// (`checks`) checks the row of `focus` (#2063).
    @MainActor
    init(
        rows: [BarWindowRow],
        checks: Bool = false,
        focus: WindowID? = nil,
        icons: Bool = false
    ) {
        self.checks = checks
        var order: [BarWindowRow] = []
        var grouped: [String: [Row]] = [:]
        for row in rows {
            if grouped[row.app] == nil { order.append(row) }
            grouped[row.app, default: []].append(
                Row(
                    window: row.window,
                    title: SpaceBarWindowMenu.windowName(row.title),
                    focused: checks && row.window == focus
                )
            )
        }
        let iconed = icons || order.count > 1
        groups = order.map { first in
            let all = grouped[first.app] ?? []
            return Group(
                app: first.app,
                icon: iconed ? first.icon : nil,
                rows: all,
                windowCount: all.count
            )
        }
    }
}
