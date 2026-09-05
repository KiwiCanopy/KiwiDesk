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
            "Sets the minimum window size before cascading.",
            .number("points")
        ),
        "set_swap_skips_cascade": APIRecord(
            "Sets whether swapping from a pile steps past it.",
            .boolean("enabled")
        ),
        "set_float_nudge": APIRecord(
            "Shoves a window inward when toggled to floating.",
            .boolean("enabled")
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
        "set_refusal_sound": APIRecord(
            "Also plays an alert sound whenever a blocked "
                + "keyboard action draws its refusal pill.",
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
        "get_layout_info": APIRecord(
            "Returns diagnostic info for the active Space."
        ),
        "list_monitors": APIRecord(
            "Lists connected screens with IDs and geometry."
        ),
        "debug_log": APIRecord(
            "Writes a message to the unified log.",
            .text("message", optional: true)
        ),
        "reload_config": APIRecord(
            "Reloads the configuration file from disk."
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
        "save_profile": APIRecord(
            "Saves the current configuration to a profile.",
            .text("name")
        ),
        "load_profile": APIRecord(
            "Loads a profile and applies its Spaces and "
                + "settings.",
            .text("name")
        ),
        "delete_profile": APIRecord(
            "Deletes a saved profile.",
            .text("name")
        ),
        "set_default_profile": APIRecord(
            "Sets the fallback profile for this screen count.",
            .text("name")
        ),
        "list_profiles": APIRecord(
            "Lists all available profile names."
        ),
        "get_profile_status": APIRecord(
            "Returns the active profile and whether it is dirty."
        ),
        "bind_profile_to_desktop": APIRecord(
            "Binds a profile to a macOS Desktop on the main "
                + "screen.",
            .desktop("desktop"),
            .text("profile")
        ),
    ]
}
