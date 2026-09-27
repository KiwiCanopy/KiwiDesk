import Foundation

/// Configuration or profile validation issue surfaced to the GUI
/// (#68, #39, #31).
public struct ConfigIssue: Sendable, Equatable, Identifiable {
    /// Issue condition structure rendered by the GUI: Core names
    /// the condition, never a sentence — a Core-rendered English
    /// copy could not re-render on a language switch
    /// (`ConfigIssueText`, #96, #601).
    public enum Kind: Sendable, Equatable {
        /// Profile JSON decoding failure with root cause (`ProfileBrokenText`,
        /// `config-vocabulary.md`, #246, architect review 2026-08-11).
        case profileBroken(ProfileBrokenCause)
        case luaVMUnavailable
        /// Lua execution error containing interpreter output —
        /// stays English by rule: CLI/IPC and interpreter text is
        /// never localized (`core-boundaries.md`).
        case luaError(String)
        case guiConfigUnreadable
        /// Unknown API function call with optional fuzzy match
        /// suggestion (#39).
        case unknownCall(name: String, suggestion: String?)
        /// A verb a release retired, and what replaces it — nil
        /// where nothing does (#1517, `APIReference.retired`).
        case retiredCall(name: String, replacement: String?)
        /// The shelf's font family is not installed, so the bars
        /// draw System (#1681, `BarFont.isInstalled`).
        case missingFontFamily(name: String)
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
    /// Publishes updated issues if changed from current state. The
    /// font issue is not a writer's to hand in: it is re-derived
    /// here from the live shelf on every publish (#1681).
    func setConfigIssues(_ issues: [ConfigIssue]) {
        let issues =
            issues.filter { !$0.kind.isFontIssue } + fontIssues()
        guard issues != configIssues else { return }
        configIssues = issues
        onConfigIssuesChange(issues)
    }

    /// Combines load-scoped issues with fresh profile scan.
    func refreshConfigIssues() {
        setConfigIssues(configLoadIssues + profileConfigIssues())
    }

    /// Re-derives the font issue against the settings live now —
    /// `updateBars()`'s call, the one point every settings landing
    /// passes (load, profile apply, Desktop binding, monitor change,
    /// Settings Save, a verb), so no writer owes it (#1681).
    func syncFontIssue() { setConfigIssues(configIssues) }

    /// The live shelf's family, when it is not installed (#1681).
    /// The source is approximate — the active profile's file, else
    /// the sidecar or `init.lua` — since the live shelf does not
    /// record which layer set its family.
    func fontIssues() -> [ConfigIssue] {
        let family = tiler.settings.kiwishelf.fontFamily
        guard !BarFont.isInstalled(family) else { return [] }
        let source =
            profiles.currentName.map { "\($0).json" }
            ?? (isGuiManaged ? "gui.json" : "init.lua")
        return [
            ConfigIssue(
                source: source,
                kind: .missingFontFamily(name: family)
            )
        ]
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

extension ConfigIssue.Kind {
    /// The live-derived font issue, which `setConfigIssues` owns.
    var isFontIssue: Bool {
        if case .missingFontFamily = self { return true }
        return false
    }
}
