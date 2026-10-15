import Foundation

extension APIReference {
    /// The `app_rule.*` verbs (#1685 ▸ Ruling 6c).
    static let appRuleRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the live app rules by bundle id: each app's "
                + "Space and its float, tile and ignore rules."
        ),
        "set_space": APIRecord(
            "Opens an app's new windows, by bundle id, in a Space, "
                + "live; a keep stores it.",
            .text("app"),
            .space("space")
        ),
        "remove_space": APIRecord(
            "Stops opening the app's new windows in a Space, live.",
            .text("app")
        ),
        "set_float": APIRecord(
            "Floats an app's windows by bundle id, or those whose "
                + "title has the text, live; a keep stores it.",
            .text("app"),
            .text("title", optional: true)
        ),
        "remove_float": APIRecord(
            "Removes one float rule, live.",
            .text("app"),
            .text("title", optional: true)
        ),
    ]
}
