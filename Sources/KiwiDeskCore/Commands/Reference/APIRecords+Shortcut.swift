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
        "remove": APIRecord(
            "Unbinds a chord in the default layer and saves at once.",
            .text("chord")
        ),
    ]
}
