import Foundation

extension APIReference {
    /// The `app_rule.*` verbs (#1685 ▸ Ruling 6c).
    static let appRuleRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the live app rules: each app's Space and the "
                + "float, tile and ignore rules."
        ),
        "set_space": APIRecord(
            "Opens the app's new windows in a Space, live; a keep "
                + "stores it.",
            .text("app"),
            .space("space")
        ),
        "remove_space": APIRecord(
            "Stops opening the app's new windows in a Space, live.",
            .text("app")
        ),
        "set_float": APIRecord(
            "Floats the app's windows, or only those whose title "
                + "contains the text, live; a keep stores it.",
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
