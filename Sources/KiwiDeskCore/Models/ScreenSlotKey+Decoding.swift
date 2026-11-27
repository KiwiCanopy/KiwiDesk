import Foundation

extension KeyedDecodingContainer {
    /// A per-screen map keyed by Screen N (#3647 ▸ lane 3c): the
    /// bars' and the pocket's edges and the bars' visibilities. A key
    /// that is no `N` or `N#id` refuses the file, as `display_areas`
    /// does; an older file crosses through `ConfigMigration` first.
    func decodeScreenMap<Value: Decodable>(
        _ type: [String: Value].Type,
        forKey key: Key
    ) throws -> [String: Value]? {
        guard let map = try decodeIfPresent(type, forKey: key) else {
            return nil
        }
        if let bad = map.keys.first(where: {
            ScreenSlotKey(parsing: $0) == nil
        }) {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "not a screen number: \(bad)"
            )
        }
        return map
    }
}
