import Foundation

/// The leaves of the keep document a change report names and
/// `keep_settings` writes (#1685), as JSON Pointers (RFC 6901): a
/// screen fingerprint or a Space id may hold a dot, so a dotted
/// path could not be parsed back.
public enum KeepPointer {
    /// `path` as a pointer: `["gap", "global"]` → `/gap/global`.
    public static func string(_ path: [String]) -> String {
        path.map {
            "/"
                + $0.replacingOccurrences(of: "~", with: "~0")
                .replacingOccurrences(of: "/", with: "~1")
        }.joined()
    }

    /// The path a pointer names, or nil for one that is not a
    /// pointer.
    public static func path(_ pointer: String) -> [String]? {
        guard pointer.hasPrefix("/") else { return nil }
        return pointer.dropFirst().split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map {
            $0.replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
        }
    }

    /// The leaf paths where `old` and `new` differ. An object key
    /// present on one side only is compared against an empty
    /// object, so a group a sparse encoder omits yields its leaves
    /// rather than itself; an array is one leaf.
    public static func diff(
        _ old: JSONValue?,
        _ new: JSONValue?,
        at path: [String] = []
    ) -> [[String]] {
        if old == new { return [] }
        switch (old, new) {
        case (.object, _), (_, .object):
            let before = members(old) ?? [:]
            let after = members(new) ?? [:]
            let keys = Set(before.keys).union(after.keys).sorted()
            return keys.flatMap {
                diff(before[$0], after[$0], at: path + [$0])
            }
        default:
            return [path]
        }
    }

    /// The value at `path`, or nil where it is absent.
    public static func value(
        at path: [String],
        in root: JSONValue
    ) -> JSONValue? {
        var node = root
        for key in path {
            guard case .object(let map) = node, let next = map[key]
            else { return nil }
            node = next
        }
        return node
    }

    /// `root` with the leaf at `path` set to `value`, or removed
    /// where `value` is nil; missing groups are made on the way,
    /// and a group a removal empties goes with it, so a map entry
    /// whose leaves all left is no entry rather than an empty one
    /// its decoder refuses.
    public static func setting(
        _ value: JSONValue?,
        at path: [String],
        in root: JSONValue
    ) -> JSONValue {
        guard let key = path.first else { return value ?? root }
        var map = members(root) ?? [:]
        if path.count == 1 {
            map[key] = value
        } else {
            let child = setting(
                value,
                at: Array(path.dropFirst()),
                in: map[key] ?? .object([:])
            )
            map[key] = child == .object([:]) && value == nil ? nil : child
        }
        return .object(map)
    }

    private static func members(_ value: JSONValue?) -> [String: JSONValue]? {
        if case .object(let map)? = value { return map }
        return nil
    }
}

extension TilingSettings {
    /// These settings as the JSON their file stores.
    var keepJSON: JSONValue? { JSONValue(encoding: self) }

    /// `live` with every leaf where these settings differ from
    /// `base` taken from these — a draft's edits laid over the
    /// settings live draws now, leaf by leaf (#2262). Where the
    /// decoder refuses the edits over live, these settings whole:
    /// a Save never drops an edit it was asked to commit.
    public func rebased(
        from base: TilingSettings,
        onto live: TilingSettings
    ) -> TilingSettings {
        guard let mine = keepJSON else { return self }
        var leaves: [[String]: JSONValue?] = [:]
        for path in KeepPointer.diff(base.keepJSON, mine) {
            leaves.updateValue(
                KeepPointer.value(at: path, in: mine),
                forKey: path
            )
        }
        guard !leaves.isEmpty else { return live }
        return live.patched(leaves) ?? self
    }

    /// `patched`, where a leaf the decoder refuses beside the others
    /// costs only itself.
    func patchedLeafByLeaf(
        _ leaves: [[String]: JSONValue?]
    ) -> TilingSettings {
        guard !leaves.isEmpty else { return self }
        if let whole = patched(leaves) { return whole }
        var each = self
        for (path, value) in leaves {
            if let one = each.patched([path: value]) { each = one }
        }
        return each
    }

    /// These settings with each leaf in `leaves` set to its value,
    /// or removed where nil, through the config's own decoder — nil
    /// where that decoder refuses the result.
    func patched(_ leaves: [[String]: JSONValue?]) -> TilingSettings? {
        guard var root = keepJSON else { return nil }
        for (path, value) in leaves {
            root = KeepPointer.setting(value, at: path, in: root)
        }
        guard let data = try? JSONEncoder().encode(root) else { return nil }
        return try? JSONDecoder().decode(TilingSettings.self, from: data)
    }
}
