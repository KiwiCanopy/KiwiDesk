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
        var leaves: [[String]: JSONValue?] = [:]
        for path in paths {
            guard let verdict = judge.verdict(of: path),
                verdict.notKeepable == nil, !verdict.stored
            else { continue }
            // `updateValue`: a nil subscript write would drop the
            // entry, and a stored absence is a value to put back.
            leaves.updateValue(
                KeepPointer.value(at: path, in: stored),
                forKey: Array(path.dropFirst())
            )
        }
        let current = tiler.settings
        guard !leaves.isEmpty else { return nil }
        var saved = current.patched(leaves)
        if saved == nil {
            // A leaf the decoder refuses beside the others costs
            // only itself.
            var each = current
            for (path, value) in leaves {
                if let one = each.patched([path: value]) { each = one }
            }
            saved = each
        }
        guard let saved, saved != current else { return nil }
        return UnsavedLiveSettings(saved: saved, live: current)
    }
}
