import Foundation

/// Typo guards (#39): a metatable on the `KiwiDesk` table and
/// on every layout namespace table (`bsp`, `scroll`, …) turns
/// an unknown call into a logged did-you-mean hint instead of
/// the hard "attempt to call a nil value" error that would
/// abort the rest of init.lua.
///
/// Non-fatal must not mean invisible (the original #39 bug was
/// a typo whose only trace was a buried log line): during a
/// config load every guard hit is also recorded as a
/// `ConfigIssue`, so it reaches the menu-bar badge and the
/// Config Issues window. Outside a load — a typo inside a
/// keybinding or event closure — the hit only logs; a stale
/// "config error" badge for a runtime slip would mislead.
extension KiwiCore {
    /// Installs the guard on `KiwiDesk` and every
    /// `APIReference.namespaces` table. Must run at the end of
    /// `registerLuaAPI` so all guarded tables already exist.
    func installTypoGuards(on lua: LuaInterpreter) {
        // The reporter is registered only to be captured as an
        // upvalue below; the chunk removes the table entry, so
        // user Lua can neither call, spoof, nor break it.
        lua.register("__report_unknown") { [weak self] args in
            guard let self,
                let table = args.first?.stringValue,
                let key = args.dropFirst().first?.stringValue
            else { return .none }
            self.reportUnknownCall(table: table, key: key)
            return .none
        }
        let tables =
            ["KiwiDesk"] + APIReference.namespaces.keys.sorted()
        let installs = tables.map {
            "setmetatable(\($0), guard(\"\($0)\"))"
        }.joined(separator: "\n")
        let result = lua.run(
            """
            local report = KiwiDesk.__report_unknown
            KiwiDesk.__report_unknown = nil
            local function guard(name)
                return {
                    __index = function(_, key)
                        return function()
                            report(name, tostring(key))
                        end
                    end,
                }
            end
            \(installs)
            """
        )
        // A failed install would silently revert typos to hard
        // chunk-aborting errors — the exact #39 failure mode.
        if case .failure(let error) = result {
            onLog("typo guard install failed: \(error)")
        }
    }

    /// Runs `body` with typo-guard ConfigIssue recording armed
    /// and returns what it captured. The only way to arm the
    /// buffer — the `defer` makes a forgotten drain impossible.
    /// Not reentrant (a nested call would un-arm the outer
    /// scope); `loadConfig` is the single caller, and a
    /// reentrant `loadConfig` is already impossible because
    /// `reload_config` defers via `Task`.
    func recordingTypoIssues(
        _ body: () -> Void
    ) -> [ConfigIssue] {
        typoIssues = []
        defer { typoIssues = nil }
        body()
        return typoIssues ?? []
    }

    /// Logs the did-you-mean hint; during a config load (see
    /// `typoIssues` in KiwiCore) additionally records the typo
    /// as a ConfigIssue, deduped so a typo'd call inside a
    /// loop reports once.
    private func reportUnknownCall(table: String, key: String) {
        let qualified =
            table == "KiwiDesk" ? key : "\(table).\(key)"
        let suggestion = APIReference.suggestion(for: qualified)
        let hint =
            suggestion.map { " — did you mean '\($0)'?" } ?? ""
        onLog(
            "unknown \(table) function '\(key)'\(hint)"
                + " — see KiwiDesk.help()"
        )
        guard typoIssues != nil else { return }
        let issue = ConfigIssue(
            source: "init.lua",
            kind: .unknownCall(
                name: qualified,
                suggestion: suggestion
            )
        )
        if typoIssues?.contains(issue) == false {
            typoIssues?.append(issue)
        }
    }
}
