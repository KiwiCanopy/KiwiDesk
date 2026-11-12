import KiwiDeskCore
import SwiftUI

/// What an end key or a gesture row may run (#1871 ▸ Settings,
/// #3183): every Shortcuts-page row, grouped and ordered as the
/// page draws its groups.
@MainActor
struct SequenceActionCatalog {
    struct Group: Identifiable {
        let title: String
        let commands: [NavCommand]
        var id: String { title }
    }

    let groups: [Group]

    /// The page parts whose rows an action may run, in page order:
    /// the Built-in segment's, without the inactive layer's rows
    /// (#3199 ▸ One catalogue). A part with no rows drops out below.
    static let parts: [ShortcutsPagePart] =
        ShortcutsPagePart.parts(in: .builtIn).filter { $0 != .inactive }

    init(expander: ShortcutsFamilyRows) {
        groups = Self.parts.compactMap { part in
            guard let title = part.group?.control.text else { return nil }
            let commands = SettingKey.allCases.filter {
                $0.placement.area.flatMap(SettingsDestination.init(area:))
                    == .shortcuts
                    && $0.placement.container.flatMap(
                        ShortcutsPagePart.init
                    ) == part
            }
            .flatMap { expander.rows(for: $0) ?? [] }
            .filter { $0.unavailable == nil }
            return commands.isEmpty
                ? nil : Group(title: title, commands: commands)
        }
    }

    /// The groups narrowed to the commands whose name holds `query`;
    /// a group with none left is dropped, an empty query keeps all.
    func matching(_ query: String) -> [Group] {
        let query = query.trimmed
        guard !query.isEmpty else { return groups }
        return groups.compactMap { group in
            let hits = group.commands.filter {
                ShortcutsSheet.matchRange(of: query, in: $0.resolvedLabel)
                    != nil
            }
            return hits.isEmpty
                ? nil : Group(title: group.title, commands: hits)
        }
    }

    /// The catalogue command `lua` runs, nil for none.
    func command(running lua: String) -> NavCommand? {
        guard !lua.isEmpty else { return nil }
        return groups.lazy.flatMap(\.commands).first { $0.runs(lua) }
    }
}
