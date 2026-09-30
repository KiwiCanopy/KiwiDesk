import Foundation

/// #1230's per-profile record in the session snapshot (#1802):
/// in every capture — a quit's, the crash autosave, an in-place
/// restart's — so a profile that is not live keeps the windows it
/// remembers across a KiwiDesk restart. A stored cross-version
/// shape; each profile's entry decodes on its own, so an
/// unreadable one costs only itself.
extension StateSnapshot {
    public struct ProfileRecords: Codable, Sendable, Equatable {
        /// Profile name → Space name → window ids.
        public let byProfile: [String: [String: [UInt32]]]

        init(_ records: [String: [SpaceID: [WindowID]]]) {
            byProfile = records.mapValues { spaces in
                Dictionary(
                    uniqueKeysWithValues: spaces.map {
                        ($0.key.raw, $0.value.map(\.raw))
                    }
                )
            }
        }

        /// Keys that name one Space (`"01"` and `"1"`) are a
        /// damaged file, never a write of ours: the first wins
        /// rather than trapping at boot.
        var records: [String: [SpaceID: [WindowID]]] {
            byProfile.mapValues { spaces in
                Dictionary(
                    spaces.map {
                        (SpaceID($0.key), $0.value.map(WindowID.init))
                    },
                    uniquingKeysWith: { first, _ in first }
                )
            }
        }

        private struct NameKey: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: NameKey.self)
            var decoded: [String: [String: [UInt32]]] = [:]
            for key in c.allKeys {
                decoded[key.stringValue] = try? c.decode(
                    [String: [UInt32]].self,
                    forKey: key
                )
            }
            byProfile = decoded
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: NameKey.self)
            for (name, spaces) in byProfile {
                try c.encode(spaces, forKey: NameKey(stringValue: name))
            }
        }
    }
}
