import Foundation

/// The dispatcher verbs that tune settings, report state and
/// drive profiles (#1033).
///
/// `subscribe` lives here rather than in `commands`: it is
/// reachable over the socket but has no `KiwiDesk.subscribe`
/// on the Lua table, so `APIReference.dispatchable` inserts it
/// by hand and the census expects it here for the same reason.
extension APIReference {
    static let coreSettingRecords: [String: APIRecord] = [
        "set_gap_global": APIRecord(
            "Sets the layout gaps in points, or a table of "
                + "per-edge gaps, across all Spaces.",
            .number("size")
        ),
        "set_gap_override": APIRecord(
            "Overrides the layout gaps for one Space; a number "
                + "or a table of per-edge gaps.",
            .space("space"),
            .number("size")
        ),
        "set_min_window_size": APIRecord(
            "Sets one layout's or every layout's minimum window "
                + "size; (width, layout) sets both axes.",
            .number("width"),
            .number("height", optional: true),
            .choice("layout", MinWindowSizes.Layout.self, optional: true)
        ),
        "set_min_window_size_override": APIRecord(
            "Overrides one Space's minimum window size, whatever "
                + "its layout; (space, width) sets both axes.",
            .space("space"),
            .number("width"),
            .number("height", optional: true)
        ),
        "set_swap_skips_cascade": APIRecord(
            "Sets whether swapping from a pile steps past it.",
            .boolean("enabled")
        ),
        "set_float_placement": APIRecord(
            "Sets where a window lands when toggled to floating.",
            .choice("placement", FloatPlacement.self)
        ),
        "set_float_scale_on_display_change": APIRecord(
            "Scales floating windows when moved across screens.",
            .boolean("enabled")
        ),
        "set_resize_step": APIRecord(
            "Sets the Grow and Shrink keyboard step size in "
                + "points.",
            .integer("points")
        ),
        "reset_layout_sizing": APIRecord(
            "Undoes manual resizes back to the profile: the active "
                + "Space, one by id, or every one with `all`.",
            .space("space", optional: true)
        ),
        "set_refusal_sound": APIRecord(
            "Also plays an alert sound whenever a blocked "
                + "keyboard action draws its refusal pill.",
            .boolean("enabled")
        ),
        "set_desktop_cue": APIRecord(
            "Shows the Desktop's number on the screen that switched "
                + "after KiwiDesk's own Desktop switch.",
            .boolean("enabled")
        ),
        "set_hyper_key": APIRecord(
            "Turns a key into the Hyper modifier for this "
                + "session, or `off`; it becomes F18 until quit.",
            .choice("key", HyperSourceKey.self)
        ),
        KiwiCore.takeOverHyperRemapCommand: APIRecord(
            "Takes over a leftover Hyper remap that matches "
                + "KiwiDesk's own; it is cleared at quit."
        ),
        "set_space_transition": APIRecord(
            "Sets how a Space switch shows itself: the plate "
                + "slide, the Space and its layout, or nothing.",
            .choice("transition", SpaceTransition.self)
        ),
        "set_space_slide_duration": APIRecord(
            "Sets the Space slide's pace in milliseconds, clamped "
                + "to its band.",
            .integer("milliseconds")
        ),
        "set_mode_cue": APIRecord(
            "Shows the cycle list and the new layout on the "
                + "Space's screen after cycle_mode.",
            .boolean("enabled")
        ),
        "set_space_history": APIRecord(
            "Sets whether Space history is kept per screen or "
                + "across every screen.",
            .choice("kind", SpaceHistoryKind.self)
        ),
        "set_float_automatically": APIRecord(
            "Sets whether windows that can't be resized and apps "
                + "with no Dock icon float without a rule.",
            .boolean("enabled")
        ),
        "set_shortcut_panel_liquid_glass": APIRecord(
            "Lays a macOS 26 Liquid Glass material over the "
                + "shortcuts panel and the slow-boot notice.",
            .boolean("enabled")
        ),
        "set_new_window_placement_override": APIRecord(
            "Overrides where new windows land for one Space.",
            .space("space"),
            .choice("placement", SpawnPlacement.self)
        ),
        "set_mouse_resize": APIRecord(
            "Sets whether mouse resizes adjust layout or snap "
                + "back.",
            .choice("mode", MouseResizeMode.self)
        ),
        "enable_wake_restore": APIRecord(
            "Enables or disables window restoration after wake.",
            .boolean("enabled")
        ),
        "set_wake_restore_delay": APIRecord(
            "Sets the delay before restoring windows after wake.",
            .integer("milliseconds")
        ),
        "get_state": APIRecord(
            "Returns a snapshot of Spaces, windows, and "
                + "screens."
        ),
        "get_config_status": APIRecord(
            "Returns the Config Issues and the sync folder's status."
        ),
        "explain_window": APIRecord(
            "Explains why a window floats or tiles, its Space and "
                + "app rules, and what would change them.",
            .window("window", optional: true)
        ),
        "explain_app": APIRecord(
            "Explains what KiwiDesk knows of an app by bundle id: "
                + "ignores, processes and windows.",
            .text("app")
        ),
        "get_layout_info": APIRecord(
            "Returns diagnostic info for the active Space."
        ),
        "list_monitors": APIRecord(
            "Lists connected screens with IDs and geometry."
        ),
        "list_windows": APIRecord(
            "Lists every window's frame, screen and visibility, "
                + "or only one Space's.",
            .space("space", optional: true)
        ),
        "debug_log": APIRecord(
            "Writes a message to the unified log.",
            .text("message", optional: true)
        ),
        "reload_config": APIRecord(
            "Reloads the configuration file from disk."
        ),
        "prepare_restart": APIRecord(
            "Makes the next stop an in-place restart if the service "
                + "program passes the identity check."
        ),
        "get_work_counters": APIRecord(
            "Returns the engine's work counters since the last "
                + "reset, and resets them when passed true.",
            .boolean("reset", optional: true)
        ),
        "self_test": APIRecord(
            "Reports which private fast paths this macOS still "
                + "answers, one verdict each, changing nothing."
        ),
        "help": APIRecord(
            "Describes one command, or lists the whole API "
                + "surface.",
            .text("command", optional: true)
        ),
        "version": APIRecord(
            "Returns the KiwiDesk version and commit hash."
        ),
        "subscribe": APIRecord(
            "Streams events as newline-delimited JSON; names one or "
                + "more events, or all of them.",
            .choice("event", KiwiNotification.self, optional: true)
        ),
        KiwiCore.keepSettingsCommand: APIRecord(
            "Keeps one or more leaves a change report named in the "
                + "live profile or its shared look.",
            .text("id")
        ),
        KiwiCore.revertSettingsCommand: APIRecord(
            "Puts one or more unsaved live settings leaves back "
                + "to their stored value.",
            .text("id")
        ),
        "save_profile": APIRecord(
            "Saves the current configuration to a profile, which "
                + "claims the connected screen setup.",
            .text("name")
        ),
        "load_profile": APIRecord(
            "Loads a profile, claiming the connected screen setup "
                + "where its screen count fits.",
            .text("name")
        ),
        "delete_profile": APIRecord(
            "Deletes a saved profile.",
            .text("name")
        ),
        "set_default_profile": APIRecord(
            "Sets the fallback profile for its screen count; "
                + "refuses one that holds no screen setup.",
            .text("name")
        ),
        "list_profiles": APIRecord(
            "Lists all available profile names."
        ),
        "get_profile_status": APIRecord(
            "Returns the active profile and whether it is dirty."
        ),
        "bind_profile_to_desktop": APIRecord(
            "Binds a profile to a main-screen Desktop; screen "
                + "fingerprints after it scope it to that setup.",
            .desktop("desktop"),
            .text("profile"),
            .text("screen", optional: true)
        ),
    ]
}
