import Foundation

/// A held Space's record in the session snapshot (#1646): on its
/// own Space record, in every capture — a quit's, the crash
/// autosave, an in-place restart's — so a restart and a crash
/// both bring the hold back. A stored cross-version shape.
extension StateSnapshot {
    /// Where the Space came from, and the windows it holds that
    /// are not live members — a hidden app's, one on another
    /// Desktop — which the record's own `windows` cannot list.
    public struct HeldRecord: Codable, Sendable, Equatable {
        public let origin: HeldOrigin
        public let remembered: [UInt32]

        public init(origin: HeldOrigin, remembered: [WindowID]) {
            self.origin = origin
            self.remembered = remembered.map(\.raw)
        }

        private enum CodingKeys: String, CodingKey {
            case origin, remembered
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            origin = try c.decode(HeldOrigin.self, forKey: .origin)
            remembered =
                try c.decodeIfPresent([UInt32].self, forKey: .remembered)
                ?? []
        }
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

    /// This snapshot with Space ids renamed — the records and the
    /// active Space.
    func renamingSpaces(_ renames: [SpaceID: SpaceID]) -> StateSnapshot {
        guard !renames.isEmpty else { return self }
        func renamed(_ raw: String) -> String {
            renames[SpaceID(raw)]?.raw ?? raw
        }
        var copy = self
        copy.spaces = spaces.map { $0.renamed(to: renamed($0.id)) }
        copy.activeSpace = activeSpace.map(renamed)
        return copy
    }
}

extension StateCoordinator {
    /// The hold of live Space `id`, if it is held. A hold with no
    /// live Space has no record: nothing it names is a member the
    /// snapshot lists, so it ends at a restart.
    func heldRecord(of id: SpaceID) -> StateSnapshot.HeldRecord? {
        guard let origin = heldSpaces[id] else { return nil }
        let remembered = rememberedSpaces.filter {
            guard $0.value.space == id,
                windows[$0.key] == nil,
                !closedDepartures.contains($0.key)
            else { return false }
            // An unjudged restored filing is not carried again.
            if case .restored = $0.value {
                return !unjudgedFilings.contains($0.key)
            }
            return true
        }.keys.sorted { $0.raw < $1.raw }
        return StateSnapshot.HeldRecord(
            origin: origin,
            remembered: remembered
        )
    }
}
