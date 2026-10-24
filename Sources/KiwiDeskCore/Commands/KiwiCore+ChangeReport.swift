import Foundation

/// The change report a socket request may ask for (#1685): what
/// it touched is a diff of the keep document around `execute`,
/// never a per-verb list, so a new setter of a value the document
/// carries reports itself; every leaf is then judged by the one
/// `KeepJudge`.
extension KiwiCore {
    /// Answers a socket request, with a `ChangeReport` where it
    /// asks. A load reports what it changed like any command; its
    /// leaves come back stored.
    func answer(_ request: CommandRequest) -> CommandResponse {
        let args = request.args ?? []
        guard request.reportChanges == true else {
            return execute(request.command, args: args)
        }
        let before = keepDocument
        var response = execute(request.command, args: args)
        let after = keepDocument
        let touched = KeepPointer.diff(before, after).filter {
            Self.isSettledLeaf($0, before, after)
        }
        let watched = (request.keepWatch ?? []).compactMap(
            KeepPointer.path(_:)
        )
        let judge =
            touched.isEmpty && watched.isEmpty
            ? nil
            : keepJudge(
                live: after,
                judgingRules: (touched + watched).contains(
                    where: Self.isRulePath
                )
            )
        response.changes = ChangeReport(
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
            KeepRoot.appRules: Self.appRuleJSON(state.appRules),
            KeepRoot.floatRules: Self.floatRuleJSON(
                eventLoop.floatRules.rawRules
            ),
            KeepRoot.floatAutomatically: .bool(
                eventLoop.floatRules.guess.enabled
            ),
            KeepRoot.focusWrap: .string(focusWrap.mode.rawValue),
        ])
    }

    /// `page`'s rules as the files resolve them.
    static func storedRuleDoc(
        _ rules: RuleReachSnapshot,
        page: String
    ) -> [String: JSONValue] {
        let floats = rules.floatRules.resolved(for: page).values.flatMap { $0 }
        let auto = rules.floatAutomatically.resolved(
            RuleReachTable<Bool>.floatAutomaticallyKey,
            for: page
        )
        return [
            KeepRoot.appRules: appRuleJSON(rules.appRules.resolved(for: page)),
            KeepRoot.floatRules: floatRuleJSON(floats),
            KeepRoot.focusWrap: .string(
                (rules.focusWrap.resolved(
                    RuleReachTable<FocusWrap>.focusWrapKey,
                    for: page
                ) ?? rules.focusWrap.focusWrapBase).rawValue
            ),
            KeepRoot.floatAutomatically: .bool(
                auto ?? rules.floatAutomatically.floatAutomaticallyBase
            ),
        ]
    }

    /// The app rules as the keep document carries them.
    static func appRuleJSON(_ rules: [String: SpaceID]) -> JSONValue {
        .object(rules.mapValues { .string($0.raw) })
    }

    /// The float rules as an object, each rule a leaf of its own —
    /// an array would diff as one leaf.
    static func floatRuleJSON(_ rules: [String]) -> JSONValue {
        .object(
            Dictionary(
                rules.map {
                    (FloatRules.normalizedRule($0), JSONValue.bool(true))
                },
                uniquingKeysWith: { first, _ in first }
            )
        )
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
    /// leaf is to be judged — a caller holding leaves, never the
    /// switch path (profiles.md ▸ A change report reads one
    /// judgement, beside #1245).
    /// `judgingRules` reads the rule snapshot — every profile and
    /// `gui.json` — only where a rule leaf is judged.
    func keepJudge(
        live: JSONValue? = nil,
        judgingRules: Bool = true
    ) -> KeepJudge {
        let managed = isGuiManaged
        let stored =
            managed
            ? profiles.currentName.flatMap { try? profiles.read(name: $0) }
            : nil
        var storedDoc: JSONValue?
        let rules =
            stored == nil || !judgingRules
            ? nil : ruleReachSnapshot(reading: stored)
        if let stored {
            var modes: [String: JSONValue] = [:]
            for id in stored.declaredSpaces {
                let mode = stored.spaceModes[id] ?? .bsp
                modes[id.raw] = .string(mode.rawValue)
            }
            var doc: [String: JSONValue] = [
                KeepRoot.settings: resolvedSettings(of: stored).keepJSON
                    ?? .null,
                KeepRoot.spaceModes: .object(modes),
            ]
            // The rules as the files resolve them, from the one
            // snapshot the owner is judged by too (#1685 ▸ 6c).
            if let rules, let page = profiles.currentName {
                doc.merge(Self.storedRuleDoc(rules, page: page)) { $1 }
            }
            storedDoc = .object(doc)
        }
        return KeepJudge(
            guiManaged: managed,
            profile: stored,
            follows: stored.map(followsSharedLook) ?? false,
            live: live ?? keepDocument,
            stored: storedDoc,
            rules: rules,
            page: profiles.currentName,
            profileIsNewer: managed && stored == nil
                && liveProfileIsNewer(),
            sidecarIsNewer: managed && guiConfigWriteLatch() != nil,
            liveSettings: tiler.settings,
            liveSpaces: Set(state.workspaces.allSpaces.map(\.id))
        )
    }
}

/// Where a leaf would be kept, why it cannot be, and whether it
/// already is — the one table a report and `keep_settings` read.
struct KeepJudge {
    let guiManaged: Bool
    /// The live profile as stored, read once; nil with none live.
    let profile: Profile?
    /// Whether the live profile wears the shared look.
    let follows: Bool
    let live: JSONValue
    /// The live profile's keep document as stored; nil with none.
    let stored: JSONValue?
    /// The rule families across the files, read once; nil where
    /// `gui.json` does not own them.
    let rules: RuleReachSnapshot?
    let page: String?
    /// The live profile's file is a newer build's, which is why it
    /// reads as none (#2490).
    let profileIsNewer: Bool
    /// A store a shared write lands in is a newer build's, read
    /// before any write so the report and the keep agree (#2490).
    let sidecarIsNewer: Bool
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
            let refusal = refusal ?? latch(of: owner)
            return TouchedLeaf(
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
        case KeepRoot.appRules?, KeepRoot.floatRules?:
            known = rest.count == 1
        case KeepRoot.floatAutomatically?, KeepRoot.focusWrap?:
            known = rest.isEmpty
        default: known = false
        }
        guard known else { return leaf(.none, .unknown) }
        guard guiManaged else { return leaf(.initLua, .luaOwned) }
        if path.first == KeepRoot.appWide { return leaf(.none, .appWide) }
        guard let declared = profile?.declaredSpaces, stored != nil else {
            return leaf(.none, profileIsNewer ? .newerFormat : .noProfile)
        }
        // A path neither side holds names no setting.
        if liveValue == nil, storedValue == nil {
            return leaf(.none, .unknown)
        }
        if path.first == KeepRoot.spaceModes {
            return declared.contains(SpaceID(rest[0]))
                ? leaf(.profile) : leaf(.none, .temporarySpace)
        }
        if path.first == KeepRoot.appRules {
            if let space = liveValue?.stringValue,
                !declared.contains(SpaceID(space))
            {
                return leaf(.none, .temporarySpace)
            }
            return ruleLeaf(path, leaf)
        }
        if path.first == KeepRoot.floatAutomatically
            || path.first == KeepRoot.floatRules
            || path.first == KeepRoot.focusWrap
        {
            return ruleLeaf(path, leaf)
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

/// The keep document's top-level keys.
enum KeepRoot {
    static let settings = "settings"
    static let spaceModes = "space_modes"
    static let appWide = "app_wide"
    static let appRules = "app_rules"
    static let floatRules = "float_rules"
    static let floatAutomatically = "float_automatically"
    /// The focus-wrap setting (#2493), a rule-reach family.
    static let focusWrap = "focus_wrap"
}
