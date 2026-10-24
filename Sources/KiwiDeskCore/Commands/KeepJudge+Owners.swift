import Foundation

extension KeepJudge {
    /// The newer-format latch on the files `owner`'s keep writes.
    func latch(of owner: KeepOwner) -> NotKeepable? {
        let latched: Bool
        switch owner {
        case .profile: latched = profileIsNewer
        case .sharedLook: latched = sidecarIsNewer
        case .sharedRules: latched = sidecarIsNewer || profileIsNewer
        case .initLua, .none: latched = false
        }
        return latched ? .newerFormat : nil
    }

    /// A rule leaf's owner, read off the reach the keep's write
    /// takes, so the report and the keep never disagree (#1685).
    func ruleLeaf(
        _ path: [String],
        _ leaf: (KeepOwner, NotKeepable?) -> TouchedLeaf
    ) -> TouchedLeaf {
        guard let rules, let page else { return leaf(.none, .notWritten) }
        let shared: Bool
        switch path.first {
        case KeepRoot.appRules?:
            shared = rules.appRules.keepIsShared(path[1], editing: page)
        case KeepRoot.floatRules?:
            shared = rules.floatRules.keepIsShared(
                RuleReachTable<[String]>.app(of: path[1]),
                editing: page
            )
        case KeepRoot.focusWrap?:
            shared = rules.focusWrap.keepIsShared(
                RuleReachTable<FocusWrap>.focusWrapKey,
                editing: page
            )
        default:
            shared = rules.floatAutomatically.keepIsShared(
                RuleReachTable<Bool>.floatAutomaticallyKey,
                editing: page
            )
        }
        return leaf(shared ? .sharedRules : .profile, nil)
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
