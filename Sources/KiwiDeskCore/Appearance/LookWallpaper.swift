import Foundation

/// The picture a look sets as the wallpaper (#3478): one for every
/// screen, or one per screen number (#3647, "numbers, not
/// hardware"). Each name is a library file, `<sha256>.<ext>`, never
/// a path. Stored under one `wallpaper` key, a string or an object
/// keyed by the number's decimal spelling.
public enum LookWallpaper: Sendable, Equatable, Codable {
    case all(String)
    case perScreen([Int: String])

    /// Every library file this names: what cleanup, the sweep, a
    /// backup and an export read (#3478 ▸ the one `names` accessor).
    public var names: Set<String> {
        switch self {
        case .all(let name): [name]
        case .perScreen(let map): Set(map.values)
        }
    }

    /// The picture screen `number` wears: its own entry, else the
    /// lowest-numbered one; one picture covers every screen.
    public func name(forScreen number: Int) -> String? {
        switch self {
        case .all(let name):
            return name
        case .perScreen(let map):
            if let own = map[number] { return own }
            return map.min { $0.key < $1.key }?.value
        }
    }

    /// How many pictures it holds; 1 for one on every screen.
    public var count: Int {
        switch self {
        case .all: 1
        case .perScreen(let map): map.count
        }
    }

    /// This value fit for use: a key not `^[1-9][0-9]*$` and a name
    /// failing `isLibraryName` dropped, nil when nothing is left.
    /// Never collapses a map into `.all`.
    public var admitted: LookWallpaper? {
        switch self {
        case .all(let name):
            return Self.isLibraryName(name) ? self : nil
        case .perScreen(let map):
            let kept = map.filter {
                $0.key >= 1 && Self.isLibraryName($0.value)
            }
            return kept.isEmpty ? nil : .perScreen(kept)
        }
    }

    /// The extensions a library picture may carry (#3478 ▸ 2026-11-24,
    /// #3699).
    public static let extensions = [
        "heic", "jpg", "jpeg", "png", "tiff", "webp",
    ]

    /// Whether `name` is `<64 lowercase hex>.<extension>`.
    public static func isLibraryName(_ name: String) -> Bool {
        let parts = name.split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard parts.count == 2, extensions.contains(String(parts[1])),
            parts[0].count == 64
        else { return false }
        return parts[0].allSatisfy {
            ("0"..."9").contains($0) || ("a"..."f").contains($0)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let name = try? container.decode(String.self) {
            self = .all(name)
            return
        }
        let raw = try container.decode([String: String].self)
        var map: [Int: String] = [:]
        for (key, value) in raw {
            // A key that is no screen number is dropped at
            // admission, so it decodes as no entry here.
            guard Self.isScreenKey(key), let number = Int(key) else {
                continue
            }
            map[number] = value
        }
        self = .perScreen(map)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .all(let name):
            try container.encode(name)
        case .perScreen(let map):
            // `[Int: String]` encodes as a pair array; the stored
            // shape is an object keyed by the number.
            let raw = Dictionary(
                uniqueKeysWithValues: map.map { (String($0.key), $0.value) }
            )
            try container.encode(raw)
        }
    }

    private static func isScreenKey(_ key: String) -> Bool {
        guard let first = key.first, ("1"..."9").contains(first) else {
            return false
        }
        return key.allSatisfy { ("0"..."9").contains($0) }
            && key.count <= 6
    }
}
