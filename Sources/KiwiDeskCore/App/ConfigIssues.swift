import Foundation

/// One config-load or profile-validation problem, surfaced to
/// the GUI's error badge and Config Issues panel (#68). This is
/// the *surface* only — the typo-guard and validation cores
/// stay with #39/#31. Lua typo hits land here (#39); the #31
/// mode-list normalization is currently SILENT (it runs inside
/// pure `Codable`, out of the reporter's reach) — surfacing a
/// "was normalized" issue from a post-decode seam
/// (`profileConfigIssues()` / `configLoadIssues`) is a
/// follow-up candidate, not a promise this file already keeps.
public struct ConfigIssue: Sendable, Equatable, Identifiable {
    /// What went wrong, as STRUCTURE rather than a sentence
    /// (#96/#601). Core names the condition and the GUI renders
    /// it — `ConfigIssueText`, mirroring `Conflict` →
    /// `ConflictText`. Not because this code cannot reach `L()`
    /// (`KiwiCore` is `@MainActor` and did call it), but because
    /// copy owned by Core cannot be re-rendered on a language
    /// switch.
    ///
    /// Before this was an enum every case was a hardcoded English
    /// `String` built in Core, which `scripts/extract-keys` could
    /// not see: four of the five never entered a catalog, so no
    /// locale could translate them however complete it was.
    public enum Kind: Sendable, Equatable {
        /// A profile JSON that no longer decodes (#246), carrying
        /// why so the panel and the Settings row say the same
        /// thing about one file. The cause is the structure Core
        /// owns; `ProfileText` renders both.
        case profileUnreadable(ProfileBrokenCause)
        /// The Lua VM could not be created at all.
        case luaVMUnavailable
        /// `init.lua` raised. The payload is the interpreter's
        /// own message and stays English by the same rule as
        /// CLI/IPC errors — it is machine output, not UI copy,
        /// and translating it would break searching for it.
        case luaError(String)
        /// `gui.json` exists but no longer decodes, so its rules
        /// and shortcuts were not applied.
        case guiConfigUnreadable
        /// A `KiwiDesk.*` call the API does not have (#39), with
        /// the nearest match when one was found.
        case unknownCall(name: String, suggestion: String?)
    }

    /// The offending file, as the user knows it
    /// (`init.lua`, `gui.json`, `<profile>.json`).
    public let source: String
    public let kind: Kind
    /// The profile this issue belongs to, when it is an
    /// unreadable profile — nil for load-scoped issues
    /// (init.lua/gui.json). Lets the panel offer a per-profile
    /// remedy (Delete / Reveal) only where one applies (#246).
    public let profileName: String?

    /// Stable across locales, unlike the rendered sentence: the
    /// old id was `source + message`, so switching language would
    /// have re-keyed every row.
    public var id: String { source + "|" + String(describing: kind) }

    public init(
        source: String,
        kind: Kind,
        profileName: String? = nil
    ) {
        self.source = source
        self.kind = kind
        self.profileName = profileName
    }
}

extension KiwiCore {
    /// Publishes a fresh issue list when it differs from the
    /// current one.
    func setConfigIssues(_ issues: [ConfigIssue]) {
        guard issues != configIssues else { return }
        configIssues = issues
        onConfigIssuesChange(issues)
    }

    /// Recombines the load-scoped issues (init.lua/gui.json —
    /// fixed only by a reload) with a fresh profile scan.
    /// Called after every config load AND after every profile
    /// mutation, so deleting or re-saving a broken profile in
    /// the GUI clears its badge without an unrelated reload.
    func refreshConfigIssues() {
        setConfigIssues(
            configLoadIssues + profileConfigIssues()
        )
    }

    /// Unreadable profile JSONs, as issues — derived from the
    /// same `ProfileManager.scan()` that `allProfiles()` and
    /// `brokenProfiles()` use, so "broken" means one thing across
    /// every surface (#246), the cause included.
    func profileConfigIssues() -> [ConfigIssue] {
        profiles.scan().compactMap { name, result in
            guard case .failure(let error) = result else {
                return nil
            }
            // The raw DecodingError is cryptic (e.g. "Cannot
            // initialize Strategy from invalid String value
            // 'shortest_side'"); log it for debugging but show
            // the user a plain, actionable line. The panel row
            // now carries the remedy (Delete / Reveal), so the
            // message no longer tells them to re-save — which was
            // never possible for a file that can't be read.
            onLog("profile '\(name)' is invalid: \(error)")
            return ConfigIssue(
                source: "\(name).json",
                kind: .profileUnreadable(
                    ProfileManager.cause(of: error)
                ),
                profileName: name
            )
        }
    }
}
