@testable import KiwiDeskCore

extension AXDumpExpected {
    /// Dumps o–z.
    static let rowsOToZ: [Row] = [
        .row("outlook_reminder", .floats(.panel), .kept, .furnished),
        .row("qutebrowser", .tiles, .kept, .furnished),
        .row("qutebrowser_context_menu", .floats(.panel), .kept, nil),
        .row("qutebrowser_hide_decoration", .floats(.panel), .kept, nil),
        .row("raycast", .floats(.accessoryApp), .ignored, nil),
        .row("raycast_settings", .tiles, .kept, .furnished),
        .row("safari", .tiles, .kept, .furnished),
        .row(
            "safari_pinterest_sign_in_with_google",
            .tiles,
            .kept,
            .furnished
        ),
        .row(
            "scenario_firefox_google_meet_share_window/01_firefox",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/02_firefox",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/03_firefox",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/04_firefox",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/05_apple_controlcenter",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/06_firefox",
            nil,
            nil,
            nil
        ),
        .row(
            "scenario_firefox_google_meet_share_window/07_firefox",
            nil,
            nil,
            nil
        ),
        .row("slack", .tiles, .kept, .furnished),
        .row("slack_chat_in_a_separate_window", .tiles, .kept, .furnished),
        .row(
            "slack_huddle_share_screen_draw_on_screen_fake_window",
            .floats(.panel),
            .kept,
            .furnished
        ),
        .row(
            "slack_huddle_share_screen_floating_popup",
            .floats(.panel),
            .kept,
            .furnished
        ),
        .row(
            "slack_huddle_share_screen_target_picker",
            .floats(.panel),
            .kept,
            nil
        ),
        .row("spotify", .tiles, .kept, .furnished),
        .row("spotify_miniplayer", .floats(.panel), .kept, .furnished),
        .row("steam_1", .floats(.accessoryApp), .kept, nil),
        .row("steam_2", .floats(.panel), .kept, nil),
        .row("sublime_text_4", .tiles, .kept, .furnished),
        .row("system_settings", .tiles, .kept, .furnished),
        .row("telegram", .tiles, .kept, .furnished),
        .row("telegram_image_viewer", .floats(.panel), .kept, nil),
        .row("terminal_app", .tiles, .kept, .furnished),
        .row("transmission", .tiles, .kept, .furnished),
        .row(
            "transmission_torrent_inspector",
            .floats(.panel),
            .kept,
            .furnished
        ),
        .row("vlc_empty", .tiles, .kept, .furnished),
        .row("vlc_fullscreen", .floats(.panel), .kept, nil),
        .row("vlc_video_playing", .tiles, .kept, .furnished),
        .row("vs_code", .tiles, .kept, .furnished),
        .row("vs_code_nativeFullScreen_false", .tiles, .kept, .furnished),
        .row("vs_codium", .tiles, .kept, .furnished),
        .row("vs_codium_nativeFullScreen_false", .tiles, .kept, .furnished),
        .row("wisprFlow1", .floats(.accessoryApp), .ignored, nil),
        .row("wisprFlow2", .floats(.panel), .kept, nil),
        .row("xcode", .tiles, .kept, .furnished),
        .row("xcode_build_succeeded_popup", .floats(.panel), .kept, nil),
        .row("xcode_installing_system_components", nil, nil, nil),
        .row("xcode_open_quickly", .floats(.panel), .kept, .furnished),
        .row("xcode_quick_actions", .floats(.panel), .kept, .furnished),
        .row("xcode_settings", .floats(.panel), .kept, .furnished),
        .row("xcode_welcome_window", .floats(.panel), .kept, nil),
        .row("zebar", .floats(.accessoryApp), .kept, nil),
        .row("zed", .tiles, .kept, .furnished),
        .row("zen_browser", .tiles, .kept, .furnished),
        .row("zen_browser_pip", .floats(.panel), .kept, .furnished),
    ]
}
