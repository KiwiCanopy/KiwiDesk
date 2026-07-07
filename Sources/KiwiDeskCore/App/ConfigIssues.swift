import Foundation

/// One config-load or profile-validation problem, surfaced to
/// the GUI's error badge and Config Issues panel (#68). This is
/// the *surface* only — the typo-guard and validation cores
/// stay with #39/#31; anything they learn to detect lands here
/// as another issue.
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
    /// current one. Issues describe the *last config load*;
    /// a recheck is a `loadConfig()` away (`reload_config`).
    func setConfigIssues(_ issues: [ConfigIssue]) {
        guard issues != configIssues else { return }
        configIssues = issues
        onConfigIssuesChange(issues)
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
