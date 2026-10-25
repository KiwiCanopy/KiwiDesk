import Foundation

@testable import KiwiDeskCore

/// Renders `docs/commands.md` (#2610): one row per action a key
/// can run — kind `.action` on a channel other than the CLI —
/// each linking to the `lua-reference.md` heading that names it.
/// `ActionsPageDriftTests` holds the committed page to this.
enum ActionsPage {
    /// Why a render cannot be made.
    enum Refusal: Error, Equatable {
        /// An action's record has no summary yet.
        case pendingSummary(String)
        /// No `lua-reference.md` heading names these actions.
        case noHeading([String])
    }

    /// The command that rewrites the committed page.
    static let regenerate =
        "KIWIDESK_WRITE_ACTIONS_PAGE=1 swift test "
        + "--filter ActionsPageDriftTests"

    /// The actions the page lists, grouped as `list_commands` is.
    static var groups: [APIReference.APIGroup] {
        APIReference.groups(of: .action).compactMap { group in
            let bindable = group.entries.filter { $0.channel != .cli }
            return bindable.isEmpty
                ? nil
                : APIReference.APIGroup(
                    name: group.name,
                    entries: bindable
                )
        }
    }

    /// The page, linked against `luaReference`'s headings.
    /// `pending` names actions to read as unsummarised, so the
    /// refusal is reachable while every record is filled.
    static func render(
        luaReference: String,
        pending: Set<String> = [],
        unreleased: Bool = true
    ) throws -> String {
        let entries = groups.flatMap(\.entries)
        if let unsummarised = entries.first(where: {
            $0.record.isPending || pending.contains($0.qualifiedName)
        }) {
            throw Refusal.pendingSummary(unsummarised.qualifiedName)
        }
        let anchors = headingAnchors(in: luaReference)
        let unlinked = entries.map(\.qualifiedName)
            .filter { anchors[$0] == nil }
        guard unlinked.isEmpty else { throw Refusal.noHeading(unlinked) }
        var out = header
        if !unreleased {
            out = out.replacingOccurrences(of: "\n\(marker)\n", with: "\n")
        }
        for group in groups {
            out += "\n## \(group.name)\n\n"
            out += "| Action | What it does |\n|---|---|\n"
            for entry in group.entries {
                let name = entry.qualifiedName
                let anchor = anchors[name] ?? ""
                let summary = entry.record.summary
                    .replacingOccurrences(of: "|", with: "\\|")
                out +=
                    "| [`\(name)`](lua-reference.md#\(anchor)) "
                    + "| \(summary) |\n"
            }
        }
        return out + (unreleased ? "\n:::\n" : "\n")
    }

    /// The block marker the release strip retires; once it has,
    /// the page renders without it (`isUnreleased(_:)`).
    static let marker = ":::unreleased"

    /// Whether a committed page still carries the marker.
    static func isUnreleased(_ page: String) -> Bool {
        page.split(separator: "\n").contains { $0 == marker }
    }

    private static let header = """
        ---
        title: Actions
        description: The actions KiwiDesk can run from a key.
        ---

        # Actions

        \(marker)
        Each action below can be bound to a key with `bind`. The \
        link opens its arguments in the [Lua \
        reference](lua-reference.md). Settings and queries are \
        listed by `kiwidesk list_commands --kind setting` and \
        `--kind query` ([CLI & IPC](cli.md#discovering-commands)).

        """

    /// The Lua table a core command is spelled on in a heading.
    private static let luaTable = "KiwiDesk."

    /// Command name → anchor of the `###` or deeper heading naming
    /// it. A heading may name several commands, split on ` / ` or
    /// `, `, and may spell one on its Lua table; the
    /// anchors follow GitHub's slugger, as the site's do,
    /// counting every heading for the duplicate suffix.
    static func headingAnchors(
        in text: String
    ) -> [String: String] {
        var seen: [String: Int] = [:]
        var anchors: [String: String] = [:]
        var fenced = false
        let lines = text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        for line in lines {
            let lead = line.drop { $0 == " " }
            if lead.hasPrefix("```") || lead.hasPrefix("~~~") {
                fenced.toggle()
            }
            guard !fenced, line.hasPrefix("#") else { continue }
            let hashes = line.prefix { $0 == "#" }
            guard line.dropFirst(hashes.count).hasPrefix(" ") else {
                continue
            }
            let title = line.dropFirst(hashes.count + 1)
                .trimmingCharacters(in: .whitespaces)
            var slug = slugged(title)
            if let count = seen[slug] {
                seen[slug] = count + 1
                slug += "-\(count)"
            } else {
                seen[slug] = 1
            }
            guard hashes.count >= 3 else { continue }
            let names = title.replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: " / ", with: ", ")
                .components(separatedBy: ", ")
            for name in names {
                let bare =
                    name.hasPrefix(luaTable)
                    ? String(name.dropFirst(luaTable.count)) : name
                if anchors[bare] == nil { anchors[bare] = slug }
            }
        }
        return anchors
    }

    private static func slugged(_ title: String) -> String {
        String(
            title.lowercased().unicodeScalars.compactMap { scalar in
                if scalar == " " { return "-" }
                let kept =
                    CharacterSet.alphanumerics.contains(scalar)
                    || scalar == "-" || scalar == "_"
                return kept ? Character(scalar) : nil
            }
        )
    }
}
