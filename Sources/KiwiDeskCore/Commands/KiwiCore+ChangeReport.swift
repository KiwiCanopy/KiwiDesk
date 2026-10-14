import Foundation

/// The change report a socket request may ask for (#1685): what
/// it touched is a diff of the keep document around `execute`,
/// never a per-verb list, so a new setter of a value the document
/// carries reports itself; every leaf is then judged by the one
/// `KeepJudge`.
extension KiwiCore {
    /// Answers a socket request, with a `ChangeReport` where it
    /// asks. A request during which the epoch moved replaced the
    /// live settings rather than setting them, so it reports no
    /// leaves of its own.
    func answer(_ request: CommandRequest) -> CommandResponse {
        let args = request.args ?? []
        guard request.reportChanges == true else {
            return execute(request.command, args: args)
        }
        let epoch = settingsEpoch
        let before = keepDocument
        var response = execute(request.command, args: args)
        let after = keepDocument
        let touched =
            epoch == settingsEpoch
            ? KeepPointer.diff(before, after).filter {
                Self.isSettledLeaf($0, before, after)
            } : []
        let watched = (request.keepWatch ?? []).compactMap(
            KeepPointer.path(_:)
        )
        let judge =
            touched.isEmpty && watched.isEmpty ? nil : keepJudge(live: after)
        response.changes = ChangeReport(
            epoch: settingsEpoch,
            profile: profiles.currentName,
            touched: touched.compactMap { judge?.verdict(of: $0) },
            watched: watched.compactMap { judge?.verdict(of: $0) }
        )
        return response
    }

    /// The live values a keep can name: the settings as their file
    /// stores them, each live Space's layout, and the app-wide
    /// values by their `gui.json` groups, which a report names and
    /// no keep writes.
    var keepDocument: JSONValue {
        var modes: [String: JSONValue] = [:]
        for space in state.workspaces.allSpaces {
            modes[space.id.raw] = .string(space.mode.rawValue)
        }
        return .object([
            KeepRoot.settings: tiler.settings.keepJSON ?? .null,
            KeepRoot.spaceModes: .object(modes),
            KeepRoot.appWide: appWide.groupsJSON,
        ])
    }

    /// A Space made or dropped is no change of its layout: a mode
    /// leaf counts only where the Space is on both sides.
    private static func isSettledLeaf(
        _ path: [String],
        _ before: JSONValue,
        _ after: JSONValue
    ) -> Bool {
        guard path.first == KeepRoot.spaceModes else { return true }
        return KeepPointer.value(at: path, in: before) != nil
            && KeepPointer.value(at: path, in: after) != nil
    }

    /// The one reading of both sides a report judges against, taken
    /// once: the stored profile is read only here, and only where a
    /// leaf is to be judged (an MCP request, never the switch path).
    func keepJudge(live: JSONValue? = nil) -> KeepJudge {
        let managed = isGuiManaged
        let stored =
            managed
            ? profiles.currentName.flatMap { try? profiles.read(name: $0) }
            : nil
        var storedDoc: JSONValue?
        if let stored {
            var modes: [String: JSONValue] = [:]
            for id in stored.declaredSpaces {
                let mode = stored.spaceModes[id] ?? .bsp
                modes[id.raw] = .string(mode.rawValue)
            }
            storedDoc = .object([
                KeepRoot.settings: resolvedSettings(of: stored).keepJSON
                    ?? .null,
                KeepRoot.spaceModes: .object(modes),
            ])
        }
        return KeepJudge(
            guiManaged: managed,
            declared: profiles.active?.declaredSpaces,
            follows: sharedLook != nil && stored != nil
                && stored?.look == nil,
            live: live ?? keepDocument,
            stored: storedDoc,
            liveSettings: tiler.settings,
            liveSpaces: Set(state.workspaces.allSpaces.map(\.id))
        )
    }
}

/// Where a leaf would be kept, why it cannot be, and whether it
/// already is — the one table a report and `keep_settings` read.
struct KeepJudge {
    let guiManaged: Bool
    /// The live profile's declared Spaces; nil with none live.
    let declared: Set<SpaceID>?
    /// Whether the live profile wears the shared look.
    let follows: Bool
    let live: JSONValue
    /// The live profile's keep document as stored; nil with none.
    let stored: JSONValue?
    let liveSettings: TilingSettings
    let liveSpaces: Set<SpaceID>

    /// Whether the leaf's live value is the stored one — a removal
    /// that landed included, where neither side holds it any more.
    func holds(_ path: [String]) -> Bool {
        stored != nil
            && KeepPointer.value(at: path, in: live)
                == stored.flatMap { KeepPointer.value(at: path, in: $0) }
    }

    func verdict(of path: [String]) -> TouchedLeaf? {
        let id = KeepPointer.string(path)
        let liveValue = KeepPointer.value(at: path, in: live)
        let storedValue = self.stored.flatMap {
            KeepPointer.value(at: path, in: $0)
        }
        func leaf(_ owner: KeepOwner, _ refusal: NotKeepable? = nil)
            -> TouchedLeaf
        {
            TouchedLeaf(
                id: id,
                owner: owner,
                notKeepable: refusal,
                stored: refusal == nil && liveValue == storedValue,
                value: liveValue
            )
        }
        let rest = Array(path.dropFirst())
        let known: Bool
        switch path.first {
        case KeepRoot.appWide?: known = !rest.isEmpty
        case KeepRoot.settings?: known = !rest.isEmpty
        case KeepRoot.spaceModes?: known = rest.count == 1
        default: known = false
        }
        guard known else { return leaf(.none, .unknown) }
        guard guiManaged else { return leaf(.initLua, .luaOwned) }
        if path.first == KeepRoot.appWide { return leaf(.none, .appWide) }
        guard let declared, stored != nil else {
            return leaf(.none, .noProfile)
        }
        // A path neither side holds names no setting.
        if liveValue == nil, storedValue == nil {
            return leaf(.none, .unknown)
        }
        if path.first == KeepRoot.spaceModes {
            return declared.contains(SpaceID(rest[0]))
                ? leaf(.profile) : leaf(.none, .temporarySpace)
        }
        if namesTemporarySpace(rest, declared: declared) {
            return leaf(.none, .temporarySpace)
        }
        return Self.isLookLeaf(rest) && follows
            ? leaf(.sharedLook) : leaf(.profile)
    }

    /// Whether a settings leaf is keyed by a live Space the profile
    /// does not declare — asked of `TilingSettings.removeSpace`,
    /// the one list of what a Space owns there, so a new Space-keyed
    /// map needs no entry here.
    private func namesTemporarySpace(
        _ path: [String],
        declared: Set<SpaceID>
    ) -> Bool {
        let candidates = path.map { SpaceID($0) }.filter {
            liveSpaces.contains($0) && !declared.contains($0)
        }
        guard !candidates.isEmpty else { return false }
        let value = liveSettings.keepJSON.flatMap {
            KeepPointer.value(at: path, in: $0)
        }
        return candidates.contains { space in
            var without = liveSettings
            without.removeSpace(space)
            return without.keepJSON.flatMap {
                KeepPointer.value(at: path, in: $0)
            } != value
        }
    }
}

extension KeepJudge {
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
