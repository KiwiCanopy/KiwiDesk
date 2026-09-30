import Foundation

/// #1230's record in the session snapshot (#1802): in every
/// capture — a quit's, the crash autosave, an in-place restart's
/// — so an arrangement that is not live keeps the windows it
/// remembers across a KiwiDesk restart. One entry per saved
/// profile or composed Standard (#1829), each keyed by the
/// `HeldOrigin.Arrangement` a held Space's origin already
/// stores. A stored cross-version shape; each entry decodes on
/// its own, so an unreadable one costs only itself.
extension StateSnapshot {
    public struct ArrangementRecords: Codable, Sendable, Equatable {
        public struct Entry: Codable, Sendable, Equatable {
            public let arrangement: HeldOrigin.Arrangement
            /// Space name → window ids.
            public let spaces: [String: [UInt32]]
        }

        public let entries: [Entry]

        init(_ records: [HeldOrigin.Arrangement: [SpaceID: [WindowID]]]) {
            entries = records.map { arrangement, spaces in
                Entry(
                    arrangement: arrangement,
                    spaces: Dictionary(
                        uniqueKeysWithValues: spaces.map {
                            ($0.key.raw, $0.value.map(\.raw))
                        }
                    )
                )
            }
            .sorted { $0.arrangement.logLabel < $1.arrangement.logLabel }
        }

        /// Keys that name one Space (`"01"` and `"1"`), or one
        /// arrangement twice, are a damaged file, never a write of
        /// ours: the first wins rather than trapping at boot.
        var records: [HeldOrigin.Arrangement: [SpaceID: [WindowID]]] {
            Dictionary(
                entries.map { entry in
                    (
                        entry.arrangement,
                        Dictionary(
                            entry.spaces.map {
                                (
                                    SpaceID($0.key),
                                    $0.value.map(WindowID.init)
                                )
                            },
                            uniquingKeysWith: { first, _ in first }
                        )
                    )
                },
                uniquingKeysWith: { first, _ in first }
            )
        }

        /// Consumes an unreadable element so the next one is read.
        private struct Skipped: Decodable {
            init(from decoder: Decoder) throws {}
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            var kept: [Entry] = []
            while !c.isAtEnd {
                if let entry = try? c.decode(Entry.self) {
                    kept.append(entry)
                } else {
                    _ = try c.decode(Skipped.self)
                }
            }
            entries = kept
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            for entry in entries { try c.encode(entry) }
        }
    }
}
