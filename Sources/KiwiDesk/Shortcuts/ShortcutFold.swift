import Foundation
import KiwiDeskCore

/// Folds the shortcuts overview (#2312): a regular digit ladder —
/// consecutive numbers on one modifier set, each on its own digit
/// key, none renamed — and a mirrored set every member of which is
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

        var isSpace: Bool {
            self == .goToSpace || self == .moveToSpace
                || self == .moveToSpaceFollow
        }
    }

    /// Where a catalog row sits in its family: a ladder's number,
    /// or a set member's place in the folded label.
    struct Place: Equatable, Sendable {
        let family: Family
        let position: Int
    }

    /// What the builder knows of a row that may fold.
    struct Tag: Equatable, Sendable {
        let place: Place
        /// The rendered modifiers and key, e.g. "⌃⌥" and "3".
        let modifiers: String
        let key: String
        /// Whether a ladder row sits on its own number's digit key,
        /// judged by key code so every keyboard layout folds alike.
        let ownDigit: Bool
        /// Whether a ladder row names its number plainly: no Space
        /// icon and no Desktop away.
        let plain: Bool

        var family: Family { place.family }
        var position: Int { place.position }
    }

    /// The tag a row built from `command` carries, nil for one at
    /// no place.
    @MainActor static func tag(
        for command: NavCommand,
        at place: Place?,
        combo: KeyCombo?,
        rendered: String
    ) -> Tag? {
        guard let place, let combo else { return nil }
        let modifiers = ComboSymbols.modifierSymbols(combo.modifiers)
        let digit = KeypadKeys.digits.first {
            $0.legend == String(place.position)
        }
        let named = place.family.isSpace && command.icon != nil
        return Tag(
            place: place,
            modifiers: modifiers,
            key: String(rendered.dropFirst(modifiers.count)),
            ownDigit: digit?.row == combo.keyCode,
            plain: !named && command.unavailable == nil
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
            return tag.plain && tag.ownDigit
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
            let keys = group.compactMap(\.fold?.key)
            combo = tag.modifiers + keys[0] + "–" + keys[keys.count - 1]
        } else {
            label = setLabel(tag.family)
            spoken = nil
            combo = setCombo(group.compactMap(\.fold))
        }
        var row = ShortcutRow(
            id: "fold:\(tag.family.rawValue):\(tag.position)",
            label: label,
            combo: combo,
            icon: ShortcutsReferenceBuilder.foldIcon(for: tag.family)
                ?? first.icon
        )
        row.spokenLabel = spoken
        row.members = group
        return row
    }

    /// One shared modifier set prints once, before every key.
    /// Arrows run together; any other key keeps a space, or two
    /// keys would read as one ("12", "-=").
    private static func setCombo(_ tags: [Tag]) -> String {
        let shared = Set(tags.map(\.modifiers)).count == 1
        guard shared, let modifiers = tags.first?.modifiers else {
            return tags.map { $0.modifiers + $0.key }
                .joined(separator: " ")
        }
        let keys = tags.map(\.key)
        let arrows = keys.allSatisfy {
            ["←", "→", "↑", "↓"].contains($0)
        }
        return modifiers + keys.joined(separator: arrows ? "" : " ")
    }
}

extension ShortcutRow {
    /// A folded row's members' place, read by the fold alone.
    fileprivate var position: Int { fold?.position ?? 0 }
}
