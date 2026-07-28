import KiwiDeskCore
import SwiftUI

/// The GUI boundary where a Core `ConfigIssue` becomes readable
/// text (#96/#601) — `Conflict` → `ConflictText`, mirrored.
///
/// Core detects these conditions while loading config, in code
/// that cannot reach `L()` (it is `@MainActor`), so it reports
/// the condition and this file says it in the user's language.
/// Until #601 four of the five were hardcoded English built in
/// Core, invisible to `scripts/extract-keys` and therefore
/// untranslatable in every locale; routing them through here is
/// what puts them in the catalogs.
enum ConfigIssueText {
    /// The sentence for one issue, in the user's language.
    @MainActor
    static func message(for kind: ConfigIssue.Kind) -> String {
        switch kind {
        case .profileUnreadable:
            return L(
                "config_issues.profile_unreadable",
                "Couldn't be loaded — it was saved by a "
                    + "different version or edited by hand."
            )
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
