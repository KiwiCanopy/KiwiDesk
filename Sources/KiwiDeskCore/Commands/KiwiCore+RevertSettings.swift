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
        let ids = args.compactMap(\.stringValue)
        guard !ids.isEmpty, ids.count == args.count else {
            return .fail("expected leaf ids from a change report")
        }
        let outcome = revertUnsavedLive(ids)
        return .ok(
            .object([
                "reverted": .array(
                    outcome.reverted.sorted().map(JSONValue.string)
                ),
                "not_revertable": .array(
                    outcome.refused.sorted().map(JSONValue.string)
                ),
            ])
        )
    }

    /// Puts the named unsaved leaves back live (#2411); ids are
    /// keep ids, as `UnsavedLiveSettings.leaves` holds them. A leaf
    /// already as stored counts as reverted; one no keep could
    /// write, or outside `settings`, is refused.
    @discardableResult
    public func revertUnsavedLive(_ ids: [String]) -> LiveRevertOutcome {
        let leaves = unsavedLiveLeaves() ?? [:]
        let judge = keepJudge(judgingRules: false)
        var chosen: [[String]: JSONValue?] = [:]
        var reverted: [String] = []
        var refused: [String] = []
        var pending: [String] = []
        for id in ids {
            guard let path = KeepPointer.path(id),
                path.first == KeepRoot.settings
            else {
                refused.append(id)
                continue
            }
            if let stored = leaves[Array(path.dropFirst())] {
                chosen.updateValue(stored, forKey: Array(path.dropFirst()))
                pending.append(id)
            } else if judge.verdict(of: path)?.stored == true {
                reverted.append(id)
            } else {
                refused.append(id)
            }
        }
        let current = tiler.settings
        let back = current.patchedLeafByLeaf(chosen)
        if back != current {
            tiler.settings = back
            // An explicit apply, as a Settings Save's (§5).
            retile(pass: .apply)
            refreshStickyReach()
        }
        let after = keepJudge(judgingRules: false)
        for id in pending {
            let verdict = KeepPointer.path(id).flatMap(after.verdict(of:))
            let landed = verdict?.stored == true
            if landed {
                reverted.append(id)
            } else {
                refused.append(id)
            }
        }
        return LiveRevertOutcome(reverted: reverted, refused: refused)
    }
}

/// What a live revert did (#2411): the keep ids it put back, and
/// those it could not.
public struct LiveRevertOutcome: Equatable {
    public let reverted: [String]
    public let refused: [String]
}
