import Foundation

/// The held Spaces a snapshot carries (#1646): every capture —
/// a quit's, the autosave, an in-place restart's — so a restart
/// and a crash both bring them back. A stored cross-version
/// shape, decoded record by record.
extension StateSnapshot {
    /// One held Space: its live id and where it came from.
    public struct HeldRecord: Codable, Sendable, Equatable {
        public let id: String
        public let origin: HeldOrigin

        public init(id: SpaceID, origin: HeldOrigin) {
            self.id = id.raw
            self.origin = origin
        }

        public var spaceID: SpaceID { SpaceID(id) }
    }

    /// A record this build cannot read costs only itself, and a
    /// file with no list (an older build's) reads as none.
    static func decodeHeld<Key: CodingKey>(
        from c: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) -> [HeldRecord] {
        let list = try? c.decodeIfPresent(
            [Lossy<HeldRecord>].self,
            forKey: key
        )
        return (list ?? []).compactMap(\.value)
    }

    /// This snapshot with each window record transformed and
    /// every other field as captured.
    func mappingWindowRecords(
        _ transform: (WindowRecord) -> WindowRecord
    ) -> StateSnapshot {
        var copy = self
        copy.windows = windows.map(transform)
        return copy
    }

    /// This snapshot with Space ids renamed — records, the active
    /// Space and the held list alike.
    func renamingSpaces(_ renames: [SpaceID: SpaceID]) -> StateSnapshot {
        guard !renames.isEmpty else { return self }
        func renamed(_ raw: String) -> String {
            renames[SpaceID(raw)]?.raw ?? raw
        }
        var copy = self
        copy.spaces = spaces.map { $0.renamed(to: renamed($0.id)) }
        copy.activeSpace = activeSpace.map(renamed)
        copy.held = held.map {
            HeldRecord(id: SpaceID(renamed($0.id)), origin: $0.origin)
        }
        return copy
    }
}

/// A value decoded on its own: nil where it cannot be read.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

extension StateCoordinator {
    /// The held Spaces a snapshot records, in bar order.
    var heldRecords: [StateSnapshot.HeldRecord] {
        workspaces.allSpaces.compactMap { space in
            heldSpaces[space.id].map {
                StateSnapshot.HeldRecord(id: space.id, origin: $0)
            }
        }
    }
}
