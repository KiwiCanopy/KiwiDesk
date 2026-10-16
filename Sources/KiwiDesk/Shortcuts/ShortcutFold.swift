import Foundation
import KiwiDeskCore

/// Folds the shortcuts overview (#2312): a regular digit ladder —
/// consecutive numbers on one modifier set, each on its own digit,
/// none renamed — and a mirrored set every member of which is
/// bound each become one row, holding the rows they stand for so
/// a search can open them again. Anything irregular stays its own
/// row, so no bound key is ever hidden. Settings never folds: each
/// chord there must stay rebindable.
enum ShortcutFold {
    /// The families that fold.
    enum Family: String, CaseIterable, Sendable {
        case goToSpace, moveToSpace, moveToSpaceFollow
        case goToDesktop, moveToDesktop, moveToDesktopFollow
        case focusDirections, swapDirections
        case spaceStep, spaceHistory, layoutCycle
        case width, height

        /// The pairs and quartets: how many members a full set holds.
        var setSize: Int? {
            switch self {
            case .focusDirections, .swapDirections: return 4
            case .spaceStep, .spaceHistory, .layoutCycle, .width,
                .height:
                return 2
            default: return nil
            }
        }
    }

    /// What the builder knows of a row that may fold.
    struct Tag: Equatable, Sendable {
        let family: Family
        /// A ladder's number, or a set member's place in the label.
        let position: Int
        /// The rendered modifiers and key, e.g. "⌃⌥" and "3".
        let modifiers: String
        let key: String
        /// Whether a ladder row names its number plainly: no Space
        /// name, icon or live-only chip, no Desktop away.
        let plain: Bool
    }

    /// The tag a command carries, nil for one that never folds.
    @MainActor static func tag(
        for command: NavCommand,
        combo: KeyCombo?,
        rendered: String
    ) -> Tag? {
        guard let combo else { return nil }
        let modifiers = ComboSymbols.modifierSymbols(combo.modifiers)
        let key = String(rendered.dropFirst(modifiers.count))
        if let (family, number) = ladder(command.lua) {
            let named =
                family.isSpace
                && (command.icon != nil || command.liveOnly != nil)
            return Tag(
                family: family,
                position: number,
                modifiers: modifiers,
                key: key,
                plain: !named && command.unavailable == nil
            )
        }
        guard let (family, position) = member(command.lua) else {
            return nil
        }
        return Tag(
            family: family,
            position: position,
            modifiers: modifiers,
            key: key,
            plain: true
        )
    }

    /// `rows` with every regular ladder run and every complete set
    /// folded into one row at its first member's place.
    @MainActor static func folded(_ rows: [ShortcutRow]) -> [ShortcutRow] {
        var groups: [[ShortcutRow]] = []
        let byFamily = Dictionary(grouping: rows.filter { $0.fold != nil }) {
            $0.fold!.family
        }
        for (family, members) in byFamily {
            if let size = family.setSize {
                if members.count == size {
                    groups.append(members.sorted { $0.position < $1.position })
                }
            } else {
                groups += runs(members)
            }
        }
        var lead: [String: ShortcutRow] = [:]
        var folded: Set<String> = []
        let index = Dictionary(
            uniqueKeysWithValues: rows.enumerated().map { ($1.id, $0) }
        )
        for group in groups where group.count >= 2 {
            let first = group.min {
                (index[$0.id] ?? 0) < (index[$1.id] ?? 0)
            }!
            lead[first.id] = foldedRow(group)
            folded.formUnion(group.map(\.id))
        }
        return rows.compactMap { row in
            if let row = lead[row.id] { return row }
            return folded.contains(row.id) ? nil : row
        }
    }

    /// A ladder family's regular runs: plain rows on their own
    /// digit, consecutive and on one modifier set.
    private static func runs(_ rows: [ShortcutRow]) -> [[ShortcutRow]] {
        let regular = rows.filter {
            guard let tag = $0.fold else { return false }
            return tag.plain && tag.key == String(tag.position)
        }
        .sorted { $0.position < $1.position }
        var out: [[ShortcutRow]] = []
        for row in regular {
            if let last = out.last?.last, let tag = last.fold,
                let next = row.fold,
                next.position == tag.position + 1,
                next.modifiers == tag.modifiers
            {
                out[out.count - 1].append(row)
            } else {
                out.append([row])
            }
        }
        return out
    }

    @MainActor private static func foldedRow(
        _ group: [ShortcutRow]
    ) -> ShortcutRow {
        let first = group[0]
        let tag = first.fold!
        let label: String
        let spoken: String?
        let combo: String
        if tag.family.setSize == nil {
            let low = tag.position
            let high = group.last!.position
            label = ladderLabel(
                tag.family,
                range: L("shortcuts.fold.range", "%1$d–%2$d", low, high)
            )
            spoken = ladderLabel(
                tag.family,
                range: L(
                    "shortcuts.fold.range.spoken",
                    "%1$d to %2$d",
                    low,
                    high
                )
            )
            combo = tag.modifiers + "\(low)–\(high)"
        } else {
            label = setLabel(tag.family)
            spoken = nil
            combo = setCombo(group.compactMap(\.fold))
        }
        var row = ShortcutRow(
            id: "fold:\(tag.family.rawValue):\(tag.position)",
            label: label,
            combo: combo,
            icon: tag.family.isSpace
                ? "squares.below.rectangle" : first.icon
        )
        row.spokenLabel = spoken
        row.members = group
        return row
    }

    /// One shared modifier set prints once, before every key.
    private static func setCombo(_ tags: [Tag]) -> String {
        let shared = Set(tags.map(\.modifiers)).count == 1
        guard shared, let modifiers = tags.first?.modifiers else {
            return tags.map { $0.modifiers + $0.key }
                .joined(separator: " ")
        }
        let keys = tags.map(\.key)
        let joiner = keys.allSatisfy { $0.count == 1 } ? "" : " "
        return modifiers + keys.joined(separator: joiner)
    }

    /// The ladder's number and family for a `KiwiDesk.<verb>(n)`
    /// call on a Space or Desktop named by digits alone.
    private static func ladder(_ lua: String) -> (Family, Int)? {
        let verbs: [(String, Family)] = [
            ("focus_space", .goToSpace),
            ("move_to_space", .moveToSpace),
            ("move_to_space_and_follow", .moveToSpaceFollow),
            ("focus_desktop", .goToDesktop),
            ("move_to_desktop", .moveToDesktop),
            ("move_to_desktop_and_follow", .moveToDesktopFollow),
        ]
        for (verb, family) in verbs {
            let prefix = "KiwiDesk.\(verb)("
            guard lua.hasPrefix(prefix), lua.hasSuffix(")") else {
                continue
            }
            let arg = lua.dropFirst(prefix.count).dropLast()
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if let number = Int(arg), String(number) == arg {
                return (family, number)
            }
        }
        return nil
    }

    /// A set member's family and its place in the folded label.
    /// A resize row matches whatever step the user set.
    @MainActor private static func member(
        _ lua: String
    ) -> (Family, Int)? {
        for (axis, family) in [("x", Family.width), ("y", .height)] {
            let prefix = "KiwiDesk.resize(\"\(axis)\", "
            if lua.hasPrefix(prefix) {
                let shrinks = lua.dropFirst(prefix.count).hasPrefix("-")
                return (family, shrinks ? 0 : 1)
            }
        }
        for (family, luas) in setMembers {
            if let index = luas.firstIndex(of: lua) {
                return (family, index)
            }
        }
        return nil
    }

    /// Each set's members, in the order its folded label names
    /// them, read off the catalog, never typed beside it.
    @MainActor private static var setMembers: [(Family, [String])] {
        [
            (
                .focusDirections,
                KeybindingCatalog.focusDirections.map(\.lua)
            ),
            (
                .swapDirections,
                KeybindingCatalog.swapDirections.map(\.lua)
            ),
            (.spaceStep, KeybindingCatalog.spaceStepRows.map(\.lua)),
            (
                .spaceHistory,
                KeybindingCatalog.spaceHistoryRows.map(\.lua)
            ),
            (
                .layoutCycle,
                KeybindingCatalog.layoutCycleRows.map(\.lua)
            ),
        ]
    }
}

extension ShortcutFold.Family {
    var isSpace: Bool {
        self == .goToSpace || self == .moveToSpace
            || self == .moveToSpaceFollow
    }
}

extension ShortcutRow {
    /// A folded row's members' place, read by the fold alone.
    fileprivate var position: Int { fold?.position ?? 0 }
}
