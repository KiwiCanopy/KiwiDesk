import Foundation

extension APIReference {
    /// The `shortcut.*` verbs (#1685 ▸ Ruling 6c).
    static let shortcutRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the live profile's shortcuts: each layer's chords "
                + "and the Lua each one runs."
        ),
        "set": APIRecord(
            "Binds a chord to a command and its arguments, given as "
                + "a list or one by one; saved at once.",
            .text("chord"),
            .text("command"),
            .text("arguments", optional: true)
        ),
        "list_groups": APIRecord(
            "Lists the shortcut groups: the built-in ones by token "
                + "and every group a shortcut makes."
        ),
        "remove": APIRecord(
            "Unbinds a chord in the default layer and saves at once.",
            .text("chord")
        ),
        "remove_sequence": APIRecord(
            "Removes the key sequence a leader chord opens in the "
                + "default layer, whole, and saves at once.",
            .text("leader")
        ),
        "set_sequence_key": APIRecord(
            "Binds a command, its arguments a list or one by one, to "
                + "a sequence path's last key (w,h).",
            .text("leader"),
            .text("path"),
            .text("command"),
            .text("arguments", optional: true)
        ),
        "name_sequence_key": APIRecord(
            "Names a sequence's leader (empty path) or branch and sets "
                + "its symbol; saved at once.",
            .text("leader"),
            .text("path"),
            .text("name"),
            .text("symbol", optional: true)
        ),
        "remove_sequence_key": APIRecord(
            "Removes one key of a key sequence, with every key under "
                + "it; saved at once.",
            .text("leader"),
            .text("path")
        ),
    ]
}
