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
        "pull_or_spawn",
        "spawn_new",
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
        "bind_profile_to_native_space",
        "enable_wake_restore",
        "subscribe",
        "border.fit_gaps",
    ]

    /// A command that does not act on the implicit focused window:
    /// a setter (`set_*` / `*.set_*`) or a recognized non-setter.
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
}
