import Foundation

/// Settings' "Live, not saved" rows (#2262): a stored setting
/// changed live from outside Settings — `kiwidesk mcp`, the CLI,
/// a Lua call, a bar's menu row — that the live profile or the
/// shared look it wears does not store.
extension KiwiCore {
    /// The live settings with each unsaved leaf put back to its
    /// stored value, or nil where none is. "Unsaved" is the one
    /// `KeepJudge`'s verdict — keepable and not stored — so these
    /// rows and a change report never disagree (#1685); a leaf no
    /// keep can write (app-wide, a temporary Space's, a Lua-owned
    /// config's) is no row.
    ///
    /// Reads the live profile's file: call it where Settings seeds
    /// its draft, never per render (profiles.md ▸ A change report
    /// reads one judgement).
    public func savedSettingsBehindLive() -> TilingSettings? {
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
        guard !leaves.isEmpty else { return nil }
        if let whole = tiler.settings.patched(leaves) { return whole }
        // A leaf the decoder refuses beside the others costs only
        // itself.
        var settings = tiler.settings
        for (path, value) in leaves {
            if let one = settings.patched([path: value]) {
                settings = one
            }
        }
        return settings == tiler.settings ? nil : settings
    }
}
