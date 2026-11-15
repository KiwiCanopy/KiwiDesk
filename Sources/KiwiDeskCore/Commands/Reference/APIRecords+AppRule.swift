import Foundation

extension APIReference {
    /// The `app_rule.*` verbs (#1685 ▸ Ruling 6c).
    static let appRuleRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the live app rules by bundle id: Spaces, titled "
                + "Spaces, float, tile and ignore rules."
        ),
        "set_space": APIRecord(
            "Opens an app's new windows, or those titled with the "
                + "text, in a Space, live; a keep stores it.",
            .text("app"),
            .space("space"),
            .text("title", optional: true)
        ),
        "remove_space": APIRecord(
            "Stops opening the app's new windows, or those whose "
                + "title has the text, in a Space, live.",
            .text("app"),
            .text("title", optional: true)
        ),
        "set_float": APIRecord(
            "Floats an app's windows by bundle id or process name, "
                + "or those whose title has the text, live.",
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
