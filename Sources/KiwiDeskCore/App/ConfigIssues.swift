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
        /// A newer KiwiDesk wrote this store's file, so this build
        /// leaves it read-only (#2324 ruling 2). A profile takes
        /// `profileBroken(.newerFormat)` instead.
        case newerFormat(ConfigArtifact)
        /// Unknown API function call with optional fuzzy match
        /// suggestion (#39).
        case unknownCall(name: String, suggestion: String?)
        /// A verb a release retired, and what replaces it — nil
        /// where nothing does (#1517, `APIReference.retired`).
        case retiredCall(name: String, replacement: String?)
        /// The shelf's font family is not installed, so the bars
        /// draw System (#1681, `BarFont.isInstalled`).
        case missingFontFamily(name: String)
        /// A shortcut in key mode `layer` names a symbol that is no
        /// SF Symbol, so its row wears the Lua mark (#2544): a
        /// warning, the binding works.
        case unknownShortcutSymbol(
            layer: String,
            chord: String,
            symbol: String
        )
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
            issues.filter { !$0.kind.isDerived } + fontIssues()
            + shortcutSymbolIssues()
        guard issues != configIssues else { return }
        configIssues = issues
        onConfigIssuesChange(issues)
    }

    /// Combines load-scoped issues with fresh profile scan.
    func refreshConfigIssues() {
        setConfigIssues(
            configLoadIssues + newerFormatIssues()
                + profileConfigIssues()
        )
    }

    /// Re-derives the live-derived issues — `updateBars()`'s call,
    /// the one point every settings landing passes (#1681), and
    /// every keybinding install's (#2544), so no writer owes it.
    func syncDerivedIssues() { setConfigIssues(configIssues) }

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
                    profiles.brokenCause(name: name, error: error)
                ),
                profileName: name
            )
        }
    }
}

extension ConfigIssue.Kind {
    /// The live-derived issues — the font's and the shortcut
    /// symbols' — which `setConfigIssues` owns.
    var isDerived: Bool {
        switch self {
        case .missingFontFamily, .unknownShortcutSymbol: true
        default: false
        }
    }
}

extension KiwiCore {
    /// One issue per installed shortcut whose `symbol` is no SF
    /// Symbol (#2544), read off the bindings the last install left,
    /// sourced to the file holding the row.
    func shortcutSymbolIssues() -> [ConfigIssue] {
        guard let snapshot = liveKeybindingSnapshot() else { return [] }
        return snapshot.metaByChord().filter(\.meta.namesUnknownSymbol)
            .map {
                ConfigIssue(
                    source: shortcutSource(layer: $0.layer, chord: $0.chord),
                    kind: .unknownShortcutSymbol(
                        layer: $0.layer,
                        chord: $0.chord,
                        symbol: $0.meta.symbol
                    )
                )
            }
    }

    /// The file an installed row came from: the active profile's
    /// where its override holds the chord, else the sidecar or
    /// `init.lua`.
    private func shortcutSource(layer: String, chord: String) -> String {
        guard case .structured(_, let profile)? = installedKeybindings
        else { return "init.lua" }
        let overridden =
            profile?.layers.contains { held in
                held.name == layer
                    && held.bindings.contains { $0.combo == chord }
            } ?? false
        if overridden, let name = profiles.currentName {
            return "\(name).json"
        }
        return "gui.json"
    }
}

/// `KiwiCore.onConfigIssuesChange`'s shape.
public typealias ConfigIssuesChanged = @MainActor ([ConfigIssue]) -> Void
