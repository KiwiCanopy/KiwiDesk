import Foundation

/// The change report a socket request may ask for (#1685): what
/// it touched is a diff of the keep document around `execute`,
/// never a per-verb list, so a new setter reports itself.
extension KiwiCore {
    /// Answers a socket request, with a `ChangeReport` where it
    /// asks. A request during which the epoch moved replaced the
    /// live settings rather than setting them, so it reports no
    /// leaves.
    func answer(_ request: CommandRequest) -> CommandResponse {
        let args = request.args ?? []
        guard request.reportChanges == true else {
            return execute(request.command, args: args)
        }
        let epoch = settingsEpoch
        let before = keepDocument
        var response = execute(request.command, args: args)
        let paths =
            epoch == settingsEpoch
            ? KeepPointer.diff(before, keepDocument) : []
        response.changes = ChangeReport(
            epoch: settingsEpoch,
            profile: profiles.currentName,
            touched: touchedLeaves(paths)
        )
        return response
    }

    /// The live values a keep can name: the settings as their file
    /// stores them, each live Space's layout, and the app-wide
    /// values, which a change report names and no keep writes.
    var keepDocument: JSONValue {
        var modes: [String: JSONValue] = [:]
        for space in state.workspaces.allSpaces {
            modes[space.id.raw] = .string(space.mode.rawValue)
        }
        var appWide: [String: JSONValue] = [:]
        for child in Mirror(reflecting: self.appWide).children {
            guard let label = child.label else { continue }
            appWide[label] = .string(String(describing: child.value))
        }
        return .object([
            KeepRoot.settings: tiler.settings.keepJSON ?? .null,
            KeepRoot.spaceModes: .object(modes),
            KeepRoot.appWide: .object(appWide),
        ])
    }

    /// Each path as a leaf with its verdict; the live profile's
    /// file is read only where a look leaf needs its look switch.
    func touchedLeaves(_ paths: [[String]]) -> [TouchedLeaf] {
        var follows: Bool?
        let followsSharedLook = { [self] () -> Bool in
            if let follows { return follows }
            let answer = sharedLook != nil && liveLookReference == nil
            follows = answer
            return answer
        }
        return paths.map {
            keepVerdict(of: $0, followsSharedLook: followsSharedLook)
        }
    }

    /// Where the leaf at `path` would be kept, or why it cannot be
    /// — the one table a report and `keep_settings` both read.
    func keepVerdict(
        of path: [String],
        followsSharedLook: () -> Bool
    ) -> TouchedLeaf {
        let id = KeepPointer.string(path)
        func leaf(_ owner: KeepOwner, _ refusal: NotKeepable? = nil)
            -> TouchedLeaf
        {
            TouchedLeaf(id: id, owner: owner, notKeepable: refusal)
        }
        let rest = Array(path.dropFirst())
        switch path.first {
        case KeepRoot.appWide?:
            return leaf(.none, .appWide)
        case KeepRoot.settings? where !rest.isEmpty,
            KeepRoot.spaceModes? where rest.count == 1:
            break
        default:
            return leaf(.none, .unknown)
        }
        guard isGuiManaged else { return leaf(.initLua, .luaOwned) }
        guard let active = profiles.active else {
            return leaf(.none, .noProfile)
        }
        if path.first == KeepRoot.spaceModes {
            return active.declaredSpaces.contains(SpaceID(rest[0]))
                ? leaf(.profile) : leaf(.none, .temporarySpace)
        }
        return Self.isLookLeaf(rest) && followsSharedLook()
            ? leaf(.sharedLook) : leaf(.profile)
    }

    /// Whether a settings leaf belongs to a look — under one of
    /// the look's styling or colour paths.
    static func isLookLeaf(_ path: [String]) -> Bool {
        (LookKeys.all + ColorPaletteKeys.all).contains {
            let look = $0.split(separator: ".").map(String.init)
            return path.starts(with: look)
        }
    }
}

/// The keep document's top-level keys.
enum KeepRoot {
    static let settings = "settings"
    static let spaceModes = "space_modes"
    static let appWide = "app_wide"
}
