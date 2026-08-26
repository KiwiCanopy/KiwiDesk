import Foundation

/// The `KiwiDesk` table's Lua-only entry points (#1033).
///
/// **An exemplar group: every record here is written.** These
/// bypass the dispatcher, so the CLI and the IPC socket cannot
/// reach them — `list_commands` marks them `lua` on the channel
/// field, and `APIReference.suggestion` still refuses to hint at
/// them (#37). They are the only records that take a
/// `.callback`, because a Lua function cannot cross a socket.
extension APIReference {
    static let luaOnlyRecords: [String: APIRecord] = [
        "exec": APIRecord(
            "Runs a shell command in the background, optionally "
                + "calling back when it exits.",
            .text("command"),
            .callback("callback", optional: true)
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
