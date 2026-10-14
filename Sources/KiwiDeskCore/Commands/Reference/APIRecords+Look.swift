import Foundation

extension APIReference {
    /// The `look.*` verbs (#1685 ▸ Ruling 6b).
    static let lookRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the bundled and saved looks and which one is worn."
        ),
        "current": APIRecord(
            "Returns the worn look's styling and colours, and the "
                + "setter of each."
        ),
        "apply": APIRecord(
            "Wears a look live; keep_settings or save_profile "
                + "stores it.",
            .text("name")
        ),
        "save": APIRecord(
            "Saves the live look under a new name; refuses a taken "
                + "one.",
            .text("name")
        ),
        "delete": APIRecord(
            "Deletes a saved look; a bundled look cannot be deleted.",
            .text("name")
        ),
    ]
}
