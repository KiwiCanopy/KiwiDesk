import Foundation

/// Configuration or profile validation issue surfaced to the GUI
/// (#68, #39, #31).
public struct ConfigIssue: Sendable, Equatable, Identifiable {
    /// Issue condition structure rendered by GUI
    /// (`ConfigIssueText`, #96, #601).
    public enum Kind: Sendable, Equatable {
        /// Profile JSON decoding failure with root cause (`ProfileBrokenText`,
        /// `config-vocabulary.md`, #246, architect review 2026-08-11).
        case profileBroken(ProfileBrokenCause)
        case luaVMUnavailable
        /// Lua execution error containing interpreter output.
        case luaError(String)
        case guiConfigUnreadable
        /// Unknown API function call with optional fuzzy match
        /// suggestion (#39).
        case unknownCall(name: String, suggestion: String?)
    }

    /// Source filename (`init.lua`, `gui.json`, or `<profile>.json`).
    public let source: String
    public let kind: Kind
    /// Target profile name for per-profile actions (nil for global issues,
    /// #246).
    public let profileName: String?

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
    /// Publishes updated issues if changed from current state.
    func setConfigIssues(_ issues: [ConfigIssue]) {
        guard issues != configIssues else { return }
        configIssues = issues
        onConfigIssuesChange(issues)
    }

    /// Combines load-scoped issues with fresh profile scan.
    func refreshConfigIssues() {
        setConfigIssues(
            configLoadIssues + profileConfigIssues()
        )
    }

    /// Unreadable profile JSON issues derived from `ProfileManager.scan()`
    /// (#246).
    func profileConfigIssues() -> [ConfigIssue] {
        profiles.scan().compactMap { name, result in
            guard case .failure(let error) = result else {
                return nil
            }
            onLog("profile '\(name)' is invalid: \(error)")
            return ConfigIssue(
                source: "\(name).json",
                kind: .profileBroken(
                    ProfileManager.cause(of: error)
                ),
                profileName: name
            )
        }
    }
}
