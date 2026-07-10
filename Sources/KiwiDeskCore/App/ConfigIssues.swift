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
    /// The offending file, as the user knows it
    /// (`init.lua`, `gui.json`, `<profile>.json`).
    public let source: String
    public let message: String

    public var id: String { source + "|" + message }

    public init(source: String, message: String) {
        self.source = source
        self.message = message
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

    /// Unreadable profile JSONs, as issues — the same files
    /// `ProfileManager.allProfiles()` skips with only a log
    /// line today.
    func profileConfigIssues() -> [ConfigIssue] {
        profiles.list().compactMap { name in
            do {
                _ = try profiles.read(name: name)
                return nil
            } catch {
                return ConfigIssue(
                    source: "\(name).json",
                    message: "\(error)"
                )
            }
        }
    }
}
