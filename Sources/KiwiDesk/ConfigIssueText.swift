import KiwiDeskCore
import SwiftUI

/// The GUI boundary where a Core `ConfigIssue` becomes readable
/// text (#96/#601) — `Conflict` → `ConflictText`, mirrored.
///
/// Core detects these conditions while loading config and
/// reports the condition; this file says it in the user's
/// language. The reason is OWNERSHIP, not actor isolation —
/// `KiwiCore` is itself `@MainActor` and could call `L()` (it
/// did, until #601). Copy authored in Core cannot be re-rendered
/// when the user switches language, and a plain English literal
/// there never reaches `scripts/extract-keys`, so it never
/// becomes a key and no locale can translate it. That is exactly
/// how four of these five shipped untranslatable.
enum ConfigIssueText {
    /// The sentence for one issue, in the user's language.
    @MainActor
    static func message(for kind: ConfigIssue.Kind) -> String {
        switch kind {
        case .profileUnreadable(let cause):
            // Delegated, not duplicated: the Settings row under
            // App ▸ Profiles names the same file for the same
            // reason, and two strings about one condition drift
            // (#678 Phase 4 pass 9).
            return ProfileBrokenText.message(for: cause)
        case .luaVMUnavailable:
            return L(
                "config_issues.lua_vm_unavailable",
                "The Lua engine couldn't start, so none of your "
                    + "configuration was applied."
            )
        case .luaError(let detail):
            // The interpreter's own message, deliberately not
            // translated — it is machine output the user will
            // search for verbatim. Only the frame around it is
            // localized.
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
