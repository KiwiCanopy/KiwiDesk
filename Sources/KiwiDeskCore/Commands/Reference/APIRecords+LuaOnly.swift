import Foundation

/// `KiwiDesk` table Lua-only entry point records (#37, #1033).
extension APIReference {
    static let luaOnlyRecords: [String: APIRecord] = [
        "exec": APIRecord(
            "Runs a shell command in the background, calling "
                + "back when it exits.",
            .text("command"),
            .callback("callback", optional: true),
            .number("timeout", optional: true),
            .boolean("dedup", optional: true)
        ),
        "bind": APIRecord(
            "Binds a key combination in the base layer to a "
                + "function.",
            .text("combo"),
            .callback("action")
        ),
        "on": APIRecord(
            "Calls a function whenever a KiwiDesk event fires.",
            .choice("event", KiwiNotification.self),
            .callback("handler")
        ),
        "define_layer": APIRecord(
            "Defines a named alternate keybinding set, with an "
                + "optional menu bar icon.",
            .text("name"),
            .table("bindings"),
            .text("icon", optional: true)
        ),
        "switch_layer": APIRecord(
            "Makes a defined keybinding layer the active one.",
            .text("name")
        ),
        "show_shortcuts": APIRecord(
            "Opens the read-only shortcuts reference panel, or "
                + "closes it if it is open."
        ),
        "open_settings": APIRecord(
            "Opens the Settings window and brings it to the "
                + "front."
        ),
    ]
}
