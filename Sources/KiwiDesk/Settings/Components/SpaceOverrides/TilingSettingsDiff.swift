import Foundation
import KiwiDeskCore

/// How many leaves differ between two `TilingSettings` under one
/// layout's key (#794).
///
/// The Spaces panel says how many settings a Space overrides, and
/// the honest way to know is to ask the resolver and count what
/// moved — not to keep a list of overridable fields. Such a list
/// would be a third mirror of one the engine and the per-space
/// editor already carry, and `parity-tests.md` asks for a
/// forget-proof derivation past two. Reflection through `Codable`
/// gives that: a new overridable field counts here the day it is
/// added, with nothing to remember.
///
/// It counts LEAVES, not top-level keys, so an override nested
/// inside a layout's sub-object still registers as one changed
/// setting rather than collapsing its whole parent into one.
enum TilingSettingsDiff {
    /// Changed leaves under a dotted JSON path.
    ///
    /// The path is the **JSON** one, not the Swift one: a layout
    /// is `settings.stack` in Swift and `layout.stack` on the
    /// wire, because `config-vocabulary.md` derives every key
    /// from its Lua name rather than from the property. Passing
    /// the Swift spelling finds nothing and reports a confident
    /// zero, which is how this shipped its first draft.
    ///
    /// Returns 0 when either side fails to encode — impossible
    /// for a `Codable` value type, and a silent zero rather than
    /// a crash inside a preview caption if it ever happens.
    static func changedLeaves(
        from base: TilingSettings,
        to other: TilingSettings,
        under path: String
    ) -> Int {
        guard let lhs = subtree(of: base, path: path),
            let rhs = subtree(of: other, path: path)
        else { return 0 }
        var count = 0
        walk(strip(lhs), strip(rhs), &count)
        return count
    }

    /// Drops the `override` map before comparing.
    ///
    /// It rides inside a layout's own params — `layout.stack`
    /// carries both the effective values AND the per-space
    /// overrides that produce them — so a naive walk counts the
    /// storage as a third changed setting beside the two fields
    /// it stores. The caption is about what the SPACE draws
    /// differently, and the map is the mechanism rather than one
    /// of those differences.
    private static func strip(_ node: Any?) -> Any? {
        guard var dict = node as? [String: Any] else { return node }
        dict["override"] = nil
        return dict
    }

    private static func subtree(
        of settings: TilingSettings,
        path: String
    ) -> Any? {
        guard let data = try? JSONEncoder().encode(settings),
            let root = try? JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        else { return nil }
        var node: Any? = root
        for part in path.split(separator: ".") {
            node = (node as? [String: Any])?[String(part)]
        }
        return node
    }

    /// Recursive leaf comparison. A key present on one side only
    /// counts as a change — a sparse override that ADDS a field
    /// is still a departure from the defaults.
    private static func walk(
        _ lhs: Any?,
        _ rhs: Any?,
        _ count: inout Int
    ) {
        if let l = lhs as? [String: Any],
            let r = rhs as? [String: Any]
        {
            for key in Set(l.keys).union(r.keys) {
                walk(l[key], r[key], &count)
            }
            return
        }
        if !equal(lhs, rhs) { count += 1 }
    }

    /// JSON leaves are `NSNumber`, `NSString` or `NSNull` here,
    /// all of which answer `isEqual` — so one comparison covers
    /// every scalar the encoder can emit, including the `Bool`
    /// that arrives as an `NSNumber`.
    private static func equal(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): return true
        case (nil, _), (_, nil): return false
        default:
            guard let l = lhs as? NSObject,
                let r = rhs as? NSObject
            else { return false }
            return l.isEqual(r)
        }
    }
}
