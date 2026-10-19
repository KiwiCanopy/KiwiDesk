import Foundation

/// Which default shortcut rows this setup has been offered (#2324):
/// the highest Desktop the Go to Desktop top-up added a row for
/// (#1870) and the newest default generation (#2211). Kept in
/// `gui.json`, so a Mac sharing the setup never re-adds a row the
/// user deleted on another. An offer never goes back: every merge
/// takes the larger value per field.
public struct ShortcutOffer: Codable, Equatable, Sendable {
    public var desktop = 0
    public var generation = 0

    public init(desktop: Int = 0, generation: Int = 0) {
        self.desktop = desktop
        self.generation = generation
    }

    /// The larger of the two per field; `other` nil changes nothing.
    public func merged(_ other: ShortcutOffer?) -> ShortcutOffer {
        guard let other else { return self }
        return ShortcutOffer(
            desktop: max(desktop, other.desktop),
            generation: max(generation, other.generation)
        )
    }

    /// The `gui.json` key.
    static let key = "shortcut_offer"

    /// The offer the file at `url` carries, read without decoding
    /// the rest; nil where it carries none or does not read.
    static func stored(at url: URL) -> ShortcutOffer? {
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let entry = root[key],
            let bytes = try? JSONSerialization.data(withJSONObject: entry)
        else { return nil }
        return try? JSONDecoder().decode(ShortcutOffer.self, from: bytes)
    }
}
