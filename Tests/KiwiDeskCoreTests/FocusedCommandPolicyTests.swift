import Testing

@testable import KiwiDeskCore

/// Parity for the focused-command classification (#292): every
/// dispatchable command must be either an implicit-focused command
/// (guarded by the foreground preflight) or a recognized
/// unrestricted one. A new command that is neither fails this
/// suite, forcing an explicit decision instead of silently
/// slipping past the guard.
@Suite("Focused-command policy parity")
struct FocusedCommandPolicyTests {
    /// Unrestricted commands that are not setters: reads, spawns,
    /// profile ops, `focus_space`, the stream `subscribe`, and the
    /// one non-`set_` namespaced action (`border.fit_gaps`). Every
    /// other unrestricted command is a setter caught by the pattern
    /// below, so this list stays small.
    private let allowedNonSetters: Set<String> = [
        "focus_space",
        "focus_desktop",
        // Switch a Space on the focused window's screen (#1655),
        // moving no window — focus_space's class.
        "focus_space_previous",
        "focus_space_next",
        "focus_space_back",
        "focus_space_forward",
        // Act on a named space + display, not the focused window,
        // so they skip the foreground preflight (like focus_space).
        "move_space_to_display",
        "pin_space_to_display",
        "create_space",
        "delete_space",
        "focus_or_spawn",
        "spawn_new",
        // Re-lays the focused Space out, like set_mode without a
        // Space, moving no window between Spaces (#453).
        "cycle_mode",
        // Names an app, never the focused window (#1510).
        "gather",
        // Names an app too: one of its windows, never the focus
        // (#1513).
        "move_here",
        // Dims every screen around the focus, moving no window
        // (#2103).
        "kiwivision.toggle",
        // Opens a KiwiHub side, moving no window (#2265); a focus
        // command here would refuse ⌃⌥J/K/L under an ignored panel.
        "kiwihub.show",
        // The look library and the live look: no window is
        // named or moved between Spaces (#1685).
        "look.list",
        "look.current",
        "look.apply",
        "look.save",
        "look.delete",
        // The live app rules: no window is named or moved (#1685).
        "app_rule.list",
        "app_rule.remove_space",
        "app_rule.remove_float",
        // The shortcut rows, saved at once: no window moves (#1685).
        "shortcut.list",
        "shortcut.set",
        "shortcut.remove",
        "get_state",
        "get_layout_info",
        "list_monitors",
        "debug_log",
        "reload_config",
        "help",
        "version",
        "save_profile",
        "load_profile",
        "delete_profile",
        "list_profiles",
        "get_profile_status",
        "bind_profile_to_desktop",
        "enable_wake_restore",
        // Acts on a Space's stored sizing, never the focused
        // window (#764).
        "reset_layout_sizing",
        "subscribe",
        "border.fit_gaps",
        // Announces the next stop, touching no window (#930).
        "prepare_restart",
        // Reads the engine's counters, touching no window (#1508).
        "get_work_counters",
        // Reads the private paths, touching no window (#1889).
        "self_test",
        // Writes the live profile's file, touching no window
        // (#1685).
        "keep_settings",
    ]

    /// A command that does not act on the implicit focused window:
    /// a setter (`set_*` / `*.set_*`) or a recognized non-setter.
    /// This treats the `set_` spelling as unrestricted, so the
    /// exhaustiveness net below only forces enrollment for
    /// *non-setter* new commands — focused commands must never be
    /// named `set_*` (invariant documented on
    /// `FocusedCommandPolicy.focusedCommands`; `disjoint` catches
    /// an enrolled violation).
    private func isUnrestricted(_ command: String) -> Bool {
        command.hasPrefix("set_")
            || command.contains(".set_")
            || allowedNonSetters.contains(command)
    }

    @Test("Every dispatchable command is classified")
    func exhaustive() {
        let unclassified = APIReference.dispatchable.filter {
            !FocusedCommandPolicy.isFocused($0)
                && !isUnrestricted($0)
        }
        let hint = Comment(
            rawValue: "uncategorized commands (classify each in "
                + "FocusedCommandPolicy or the allow list): "
                + "\(unclassified)"
        )
        #expect(unclassified.isEmpty, hint)
    }

    @Test("Focused commands are all real dispatchable commands")
    func focusedAreDispatchable() {
        let dispatchable = Set(APIReference.dispatchable)
        for command in FocusedCommandPolicy.focusedCommands {
            #expect(
                dispatchable.contains(command),
                Comment(
                    rawValue:
                        "\(command) is not a dispatchable command"
                )
            )
        }
    }

    @Test("Focused and unrestricted classifications are disjoint")
    func disjoint() {
        for command in FocusedCommandPolicy.focusedCommands {
            #expect(
                !isUnrestricted(command),
                Comment(
                    rawValue: "\(command) is classified both "
                        + "focused and unrestricted"
                )
            )
        }
    }

    @Test("The raise-flight exemption is a set of focused verbs")
    func raiseFlightExemptIsFocused() {
        #expect(
            FocusedCommandPolicy.raiseFlightExempt.isSubset(
                of: FocusedCommandPolicy.focusedCommands
            )
        )
    }
}
