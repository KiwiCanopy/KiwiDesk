@testable import KiwiDeskCore

extension AXDumpExpected {
    /// Dumps g–n.
    static let rowsGToN: [Row] = [
        .row("ghostty", .tiles, .kept, .furnished),
        .row("ghostty_about", .tiles, .kept, .furnished),
        .row("ghostty_check_for_updates_1_dialog", .tiles, .kept, nil),
        .row(
            "ghostty_check_for_updates_2_alert",
            .floats(.panel),
            .ignored,
            nil
        ),
        .row("ghostty_config_error", .floats(.panel), .ignored, .furnished),
        .row("ghostty_quick_terminal", .floats(.panel), .ignored, nil),
        .row("ghostty_window_decorations_false", .tiles, .kept, nil),
        .row("intellij", .tiles, .kept, .furnished),
        .row("intellij_background_tasks", .floats(.panel), .kept, nil),
        .row("intellij_context_menu", .floats(.panel), .kept, nil),
        .row("intellij_native_open_window", .floats(.panel), .kept, nil),
        .row("intellij_quick_doc_popup", .floats(.panel), .kept, nil),
        .row("intellij_rebase_dialog", .tiles, .kept, .furnished),
        .row("iphonesimulator", .tiles, .kept, .furnished),
        .row("iterm2", .tiles, .kept, .furnished),
        .row("iterm2_hotkey_window", .tiles, .kept, .furnished),
        .row("iterm2_no_title_bar", .tiles, .kept, .furnished),
        .row("jetbrains_toolbox", .floats(.accessoryApp), .ignored, nil),
        .row("karabiner_event_viewer", .tiles, .kept, .furnished),
        .row("karabiner_settings", .tiles, .kept, .furnished),
        .row("kitty_quick_access", .floats(.accessoryApp), .ignored, nil),
        .row("macos_capslock_popup_safari", .floats(.panel), .kept, nil),
        .row("macos_capslock_popup_textedit", .floats(.panel), .kept, nil),
        .row(
            "macos_join_network",
            .floats(.accessoryApp),
            .ignored,
            .furnished
        ),
        .row(
            "macos_share_window_purple_pill_sublime",
            .floats(.panel),
            .kept,
            nil
        ),
        .row("marta", .tiles, .kept, .furnished),
        .row("microsoft_edge", .tiles, .kept, .furnished),
        .row("microsoft_edge_pip", .floats(.panel), .kept, .furnished),
        .row("mpv_fullscreen", .floats(.panel), .kept, nil),
        .row("mpv_windowed", .tiles, .kept, .furnished),
        .row("nomachine_session_1", .floats(.accessoryApp), .kept, nil),
        .row("nomachine_session_2", .floats(.accessoryApp), .kept, .furnished),
        .row("nomachine_welcome_window_1", .floats(.accessoryApp), .kept, nil),
        .row(
            "nomachine_welcome_window_2",
            .floats(.accessoryApp),
            .kept,
            .furnished
        ),
    ]
}
