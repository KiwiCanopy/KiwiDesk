import KiwiDeskCore

/// What a Save's rule half did (#1393).
enum RuleReachWrite: Equatable {
    /// No checklist, or nothing it reaches changed.
    case nothing
    /// Every reached file and the base were written.
    case landed
    /// A write failed; some files may have been written.
    case failed
}

/// A Save's rule half and the edit-target menu (#1393), split
/// from `SettingsModel+RuleReach` at the file ceiling.
extension SettingsModel {
    /// Writes every profile file and the shared rules the draft's
    /// checklist reached, and says what happened — the one answer
    /// every Save door reads, so none infers from its own control
    /// flow which half landed. A stored page's own shortcut
    /// override is left to its Save's diff (`overwriteProfile`),
    /// which carries its layer structure too.
    func saveRuleReach() -> RuleReachWrite {
        var written = RuleReachWrite.nothing
        // The lenses after their chords and marks, ahead of every
        // gui.json write of the Save — on every door (#2103).
        core.withLensReachHeld {
            written = writeRuleReach()
            if written != .failed { saveLensHalf() }
        }
        return written
    }

    private func writeRuleReach() -> RuleReachWrite {
        // With no page — a built-in live — the layered snapshot
        // carries the lens crossings alone.
        guard let reach = encodedReach ?? layeredReach, reach.isEdited
        else {
            return .nothing
        }
        do {
            try core.saveRuleReach(reach, keysLeftTo: editingProfile)
            return .landed
        } catch {
            profileWarning = L(
                "profiles.save_failed",
                "Saving failed: %1$@",
                NewerFormatText.detail(error)
            )
            core.onLog("rule reach save failed: \(error)")
            return .failed
        }
    }

    /// Whether Save as new profile… waits: a checklist choice
    /// reaches other profiles, which a copy cannot carry. A plain
    /// value edit is the copy's own.
    var copyWaitsOnReach: Bool { !reachEdits.isEmpty }

    /// Profiles in the order the edit-target menu lists them: the
    /// loaded one first, then the connected screen count's, then
    /// the rest by count, each in saved order.
    var profileMenuOrder: [String] {
        let loaded = activeProfile
        let connected = displays.count
        let rest = profileSummaries.filter { $0.name != loaded }
        let ordered = rest.enumerated().sorted { lhs, rhs in
            let l = lhs.element.count
            let r = rhs.element.count
            if (l == connected) != (r == connected) {
                return l == connected
            }
            if l != r { return l > r }
            return lhs.offset < rhs.offset
        }.map(\.element.name)
        return (loaded.map { [$0] } ?? []) + ordered
    }
}
