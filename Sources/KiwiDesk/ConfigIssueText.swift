import KiwiDeskCore
import SwiftUI

/// Localizes Core `ConfigIssue` descriptions for display (#96, #601).
enum ConfigIssueText {
    /// The sentence for one issue, in the user's language.
    @MainActor
    static func message(for kind: ConfigIssue.Kind) -> String {
        switch kind {
        case .profileBroken(let cause):
            // Shared with Settings ▸ Profiles row (#678).
            return ProfileBrokenText.message(for: cause)
        case .luaVMUnavailable:
            return L(
                "config_issues.lua_vm_unavailable",
                "The Lua engine couldn't start, so none of your "
                    + "configuration was applied."
            )
        case .luaError(let detail):
            // Preserves raw error message inside localized frame.
            return L(
                "config_issues.lua_error",
                "This file raised an error: %1$@",
                detail
            )
        case .guiConfigUnreadable:
            return L(
                "config_issues.gui_config_unreadable",
                "Couldn't be read, so your rules and shortcuts "
                    + "were not applied."
            )
        case .unknownCall(let name, let suggestion):
            guard let suggestion else {
                return L(
                    "config_issues.unknown_call",
                    "Unknown call '%1$@'.",
                    name
                )
            }
            return L(
                "config_issues.unknown_call_suggestion",
                "Unknown call '%1$@' — did you mean '%2$@'?",
                name,
                suggestion
            )
        }
    }
}
