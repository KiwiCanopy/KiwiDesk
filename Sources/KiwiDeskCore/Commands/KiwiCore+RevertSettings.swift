import Foundation

/// `revert_settings` (#2411), the twin of `keep_settings`: the
/// named unsaved live leaves put back to the value their owner
/// stores — the live profile or the shared look it wears — and
/// applied live. Settings leaves alone: a Space's layout picked
/// live is the session's and Revert never ends it (#1179), and a
/// rule leaf reverts through its page. Drift is left alone by
/// ruling (#2411). What it answers as reverted is re-judged after
/// the apply, so a leaf that did not land is never told as one.
extension KiwiCore {
    /// The verb's name, read where a caller names it.
    nonisolated public static let revertSettingsCommand = "revert_settings"

    /// `revert_settings(id…)`.
    func revertSettings(_ args: [JSONValue]) -> CommandResponse {
        let ids = args.compactMap { arg -> String? in
            guard case .string(let id) = arg else { return nil }
            return id
        }
        guard !ids.isEmpty, ids.count == args.count else {
            return .fail("expected leaf ids from a change report")
        }
        let outcome = revertUnsavedLive(ids)
        let refused: [JSONValue] = outcome.refused.sorted {
            $0.key < $1.key
        }.map {
            .object([
                "id": .string($0.key),
                "reason": .string($0.value.rawValue),
            ])
        }
        return .ok(
            .object([
                "reverted": .array(
                    outcome.reverted.sorted().map(JSONValue.string)
                ),
                "not_revertable": .array(refused),
            ])
        )
    }

    /// Puts the named unsaved leaves back live (#2411); ids are
    /// keep ids, as `UnsavedLiveSettings.leaves` holds them. A leaf
    /// already as stored counts as reverted. The apply is the one a
    /// sizing setter makes: settings, the session shadow of each
    /// reverted sizing leaf, an explicit retile, the sticky carry.
    @discardableResult
    public func revertUnsavedLive(_ ids: [String]) -> LiveRevertOutcome {
        let judge = keepJudge(judgingRules: false)
        let leaves = unsavedLiveLeaves(in: judge) ?? [:]
        var chosen: [[String]: JSONValue?] = [:]
        var reverted: [String] = []
        var refused: [String: RevertRefusal] = [:]
        var pending: [String] = []
        for id in ids {
            guard let path = KeepPointer.path(id),
                path.first == KeepRoot.settings
            else {
                refused[id] = .notASetting
                continue
            }
            let rest = Array(path.dropFirst())
            if let stored = leaves[rest] {
                chosen.updateValue(stored, forKey: rest)
                pending.append(id)
            } else if judge.verdict(of: path)?.stored == true {
                reverted.append(id)
            } else {
                refused[id] = .notKeepable
            }
        }
        let current = tiler.settings
        let back = current.patchedLeafByLeaf(chosen)
        if back != current {
            tiler.settings = back
            clearSessionShadows(from: current, to: back)
            // An explicit apply, as a Settings Save's (§5).
            retile(pass: .apply)
            refreshStickyReach()
        }
        let after = keepJudge(judgingRules: false)
        for id in pending {
            let verdict = KeepPointer.path(id).flatMap(after.verdict(of:))
            if verdict?.stored == true {
                reverted.append(id)
            } else {
                refused[id] = .notApplied
            }
        }
        return LiveRevertOutcome(reverted: reverted, refused: refused)
    }
}

/// What a live revert did (#2411): the keep ids it put back, and
/// those it could not, each with why.
public struct LiveRevertOutcome: Equatable {
    public let reverted: [String]
    public let refused: [String: RevertRefusal]
}

/// Why `revert_settings` left a leaf live (#2411).
public enum RevertRefusal: String, Equatable, Sendable {
    /// Not a `/settings/…` leaf: a Space's layout or a rule.
    case notASetting = "not_a_setting"
    /// Unsaved but no keep could write it (a temporary Space's,
    /// a Lua-owned config's), so nothing stores a value to revert to.
    case notKeepable = "not_keepable"
    /// Applied, and still not the stored value afterwards.
    case notApplied = "not_applied"
}
