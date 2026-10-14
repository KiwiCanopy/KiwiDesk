import Foundation

/// Renames a stored `lua` value, under that key at any depth, that
/// is exactly one of the three retired panel calls to its
/// `kiwihub.show` side (#2265, `KiwiHubMigrationTests`). Any other
/// spelling is the user's script and is left alone. Idempotent, so
/// no format floor.
extension ConfigMigration {
    /// Spelled rather than derived: a historical step keeps naming
    /// what it was written to name.
    static let retiredKiwiHubCalls: [String: String] = [
        "KiwiDesk.show_jump_to_window()": "kiwihub.show(\"windows\")",
        "KiwiDesk.show_shortcuts()": "kiwihub.show(\"shortcuts\")",
        "KiwiDesk.show_layout_picker()": "kiwihub.show(\"layouts\")",
    ]
    static let kiwiHubLuaKey = "lua"

    @Sendable
    static func migratingRetiredPanelVerbs(_ data: Data) -> Data? {
        let needles = retiredKiwiHubCalls.keys.map {
            Data(String($0.dropLast(2)).utf8)
        }
        return surgicallyApplying(
            data,
            gate: { data in needles.contains { data.range(of: $0) != nil } },
            rewriting: {
                rewritingValues(of: $0, at: kiwiHubLuaKey) {
                    ($0 as? String).flatMap { retiredKiwiHubCalls[$0] }
                }
            },
            editing: surgicallyRenamedPanelCalls
        )
    }

    /// The text with every JSON string spelling a retired call
    /// renamed where it stands; the envelope discards an edit that
    /// reached a string the walk did not.
    private static func surgicallyRenamedPanelCalls(
        _ text: String
    ) -> Data? {
        var out = text
        for (old, new) in retiredKiwiHubCalls {
            let escaped = new.replacingOccurrences(of: "\"", with: "\\\"")
            out = out.replacingOccurrences(
                of: "\"\(old)\"",
                with: "\"\(escaped)\""
            )
        }
        return out == text ? nil : out.data(using: .utf8)
    }
}
