import Foundation

/// The dispatcher verbs that tune settings, report state and
/// drive profiles (#1033).
///
/// `subscribe` lives here rather than in `commands`: it is
/// reachable over the socket but has no `KiwiDesk.subscribe`
/// on the Lua table, so `APIReference.dispatchable` inserts it
/// by hand and the census expects it here for the same reason.
///
/// Every record here is `.todo()` until #1033 phase 2 fills it;
/// `APIRecordFilledTests` counts what is left.
extension APIReference {
    static let coreSettingRecords: [String: APIRecord] = [
        "set_gap_global": .todo(),
        "set_gap_override": .todo(),
        "set_min_window_size": .todo(),
        "set_swap_skips_cascade": .todo(),
        "set_float_nudge": .todo(),
        "set_float_scale_on_display_change": .todo(),
        "set_resize_step": .todo(),
        "set_resize_feedback": .todo(),
        "set_new_window_placement_override": .todo(),
        "set_mouse_resize": .todo(),
        "enable_wake_restore": .todo(),
        "set_wake_restore_delay": .todo(),
        "get_state": .todo(),
        "get_layout_info": .todo(),
        "list_monitors": .todo(),
        "debug_log": .todo(),
        "reload_config": .todo(),
        "help": .todo(),
        "version": .todo(),
        "subscribe": .todo(),
        "save_profile": .todo(),
        "load_profile": .todo(),
        "delete_profile": .todo(),
        "set_default_profile": .todo(),
        "list_profiles": .todo(),
        "get_profile_status": .todo(),
        "bind_profile_to_desktop": .todo(),
    ]
}
