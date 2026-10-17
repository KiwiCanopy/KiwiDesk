import Foundation

/// Settings' "Live, not saved" rows (#2262): a stored setting
/// changed live from outside Settings — `kiwidesk mcp`, the CLI,
/// a Lua call, a bar's menu row — that the live profile or the
/// shared look it wears does not store.
public struct UnsavedLiveSettings: Equatable {
    /// The live settings with each unsaved leaf put back to its
    /// stored value.
    public let saved: TilingSettings
    /// The live settings, read beside `saved` in one judgement.
    public let live: TilingSettings
    /// Each unsaved leaf by its keep id (a `KeepPointer` string),
    /// mapped to `saved` with that one leaf live — what Settings
    /// reads to tell which leaves a row's Keep writes (#2368).
    public let leaves: [String: TilingSettings]

    public init(
        saved: TilingSettings,
        live: TilingSettings,
        leaves: [String: TilingSettings]
    ) {
        self.saved = saved
        self.live = live
        self.leaves = leaves
    }
}

extension KiwiCore {
    /// The settings an unsaved live leaf separates, or nil where
    /// none does. "Unsaved" is the one `KeepJudge`'s verdict —
    /// keepable and not stored — so these rows and a change report
    /// never disagree (#1685); a leaf no keep can write (a
    /// temporary Space's, a Lua-owned config's) is no row.
    ///
    /// Reads the live profile's file: a caller asks where the
    /// live settings or Settings' baseline can have moved, never
    /// per render (profiles.md ▸ A change report reads one
    /// judgement).
    public func unsavedLiveSettings() -> UnsavedLiveSettings? {
        let live = keepDocument
        let judge = keepJudge(live: live, judgingRules: false)
        guard let stored = judge.stored else { return nil }
        let root = [KeepRoot.settings]
        let paths = KeepPointer.diff(
            KeepPointer.value(at: root, in: stored),
            KeepPointer.value(at: root, in: live),
            at: root
        )
        // Every path differs, so none is stored; the verdict says
        // whether a keep could write it.
        var leaves: [[String]: JSONValue?] = [:]
        for path in paths {
            guard let verdict = judge.verdict(of: path),
                verdict.notKeepable == nil
            else { continue }
            // `updateValue`: a nil subscript write would drop the
            // entry, and a stored absence is a value to put back.
            leaves.updateValue(
                KeepPointer.value(at: path, in: stored),
                forKey: Array(path.dropFirst())
            )
        }
        let current = tiler.settings
        let saved = current.patchedLeafByLeaf(leaves)
        guard saved != current else { return nil }
        var each: [String: TilingSettings] = [:]
        for path in leaves.keys {
            var others = leaves
            others.removeValue(forKey: path)
            each[KeepPointer.string([KeepRoot.settings] + path)] =
                current.patchedLeafByLeaf(others)
        }
        return UnsavedLiveSettings(saved: saved, live: current, leaves: each)
    }

    /// Keeps the named unsaved leaves into the live profile, as
    /// `keep_settings` does (#2368); ids come from `leaves`.
    @discardableResult
    public func keepUnsavedLive(_ ids: [String]) -> LiveKeepOutcome {
        var refused: [String: NotKeepable] = [:]
        for id in ids where KeepPointer.path(id) == nil {
            refused[id] = .notWritten
        }
        let outcome = keep(paths: ids.compactMap(KeepPointer.path(_:)))
        for leaf in outcome.refused {
            refused[leaf.id] = leaf.notKeepable ?? .notWritten
        }
        return LiveKeepOutcome(
            refused: refused,
            sharedLook: outcome.kept.contains { $0.owner == .sharedLook }
        )
    }
}

/// What a Settings Keep did (#2368): the leaves it could not write,
/// by keep id, and whether a kept leaf landed in the shared look,
/// which every profile wearing it then carries.
public struct LiveKeepOutcome: Equatable {
    public let refused: [String: NotKeepable]
    public let sharedLook: Bool
}
