import Foundation

extension APIReference {
    /// The `look.*` verbs (#1685 ▸ Ruling 6b).
    static let lookRecords: [String: APIRecord] = [
        "list": APIRecord(
            "Lists the bundled and saved looks and which one is worn."
        ),
        "current": APIRecord(
            "Returns the worn look's styling, colours and each "
                + "path's setter."
        ),
        "apply": APIRecord(
            "Wears a look live, like a setter; it is not stored "
                + "until kept.",
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
