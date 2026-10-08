@testable import KiwiDeskCore

extension AXDumpExpected {
    /// Dumps a–f.
    static let rowsAToF: [Row] = [
        .row("1password", .tiles, .kept, .furnished),
        .row(
            "1password_large_type_window",
            .floats(.panel),
            .kept,
            .furnished
        ),
        .row("1password_mini_window", .floats(.panel), .kept, .furnished),
        .row("about_this_mac", .floats(.accessoryApp), .kept, .furnished),
        .row("alacritty_decorations_buttonless", .tiles, .kept, .furnished),
        .row("apple_calendar", .tiles, .kept, .furnished),
        .row("apple_calendar_settings", .tiles, .kept, .furnished),
        .row(
            "apple_followup_sign_in_to_a_new_device_confirmation",
            .floats(.accessoryApp),
            .ignored,
            nil
        ),
        .row("apple_mail", .tiles, .kept, .furnished),
        .row("apple_mail_new_email", .tiles, .kept, .furnished),
        .row("apple_mail_settings", .tiles, .kept, .furnished),
        .row("archiveutility", .tiles, .kept, .furnished),
        .row("brave", .tiles, .kept, .furnished),
        .row("brave_pip", .floats(.panel), .kept, .furnished),
        .row("calculator", .tiles, .kept, .furnished),
        .row("choose_1_5_0", .floats(.accessoryApp), .kept, nil),
        .row("chrome", .tiles, .kept, .furnished),
        .row("chrome_choose_what_to_share_popup", .floats(.panel), .kept, nil),
        .row("chrome_extensions_popup", .floats(.panel), .kept, nil),
        .row("chrome_find_in_page", .floats(.panel), .kept, nil),
        .row("chrome_pip", .floats(.panel), .kept, nil),
        .row(
            "chrome_sharing_is_in_progress_popup",
            .floats(.panel),
            .kept,
            nil
        ),
        .row("cleanshotx_monitor_1", .floats(.accessoryApp), .ignored, nil),
        .row("cleanshotx_monitor_2", .floats(.accessoryApp), .ignored, nil),
        .row("codex", .tiles, .kept, .furnished),
        .row("codex_pet_window", .floats(.panel), .kept, nil),
        .row("drracket", .tiles, .kept, .furnished),
        .row("emacs", .tiles, .kept, .furnished),
        .row("emacs_child_frame_corfu", .floats(.panel), .kept, nil),
        .row("emacs_child_frame_posframe", .floats(.panel), .kept, nil),
        .row("finder", .tiles, .kept, .furnished),
        .row("finder_quick_look", .floats(.panel), .kept, .furnished),
        .row("firefox", .tiles, .kept, .furnished),
        .row("firefox_extensions_popup", .floats(.panel), .kept, nil),
        .row(
            "firefox_mouse_hover_over_extensions_button",
            .floats(.panel),
            .kept,
            nil
        ),
        .row("firefox_mouse_hover_over_tab", .floats(.panel), .kept, nil),
        .row("firefox_non_native_fullscreen", .floats(.panel), .kept, nil),
        .row(
            "firefox_normal_window_when_non_native_fullscreen_in_background",
            .tiles,
            .kept,
            .furnished
        ),
        .row(
            "firefox_pinterest_sign_in_with_google",
            .tiles,
            .kept,
            .furnished
        ),
        .row("firefox_pip", .floats(.panel), .kept, .furnished),
    ]
}
