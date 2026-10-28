import Foundation

/// The pocket's in-place crossing (#2446, #2678).
extension StateSnapshot {
    /// The pocket list, slot by slot so an unreadable one costs only
    /// itself; where no list was written, a 4.0.0 file's one slot.
    static func decodePocket(
        _ c: KeyedDecodingContainer<CodingKeys>,
        from decoder: Decoder
    ) -> [PocketSlot] {
        if let slots = try? c.decodeIfPresent(
            [ReadableSlot].self,
            forKey: .pocket
        ) {
            return slots.compactMap(\.slot)
        }
        let single = try? decoder.container(keyedBy: SingleSlotKey.self)
            .decodeIfPresent(PocketSlot.self, forKey: .pocket)
        return single.map { [$0] } ?? []
    }

    /// 4.0.0's one slot, under the key the list took over.
    private enum SingleSlotKey: String, CodingKey { case pocket }

    /// One pocket slot, nil where it cannot be read.
    private struct ReadableSlot: Decodable {
        let slot: PocketSlot?

        init(from decoder: Decoder) throws {
            slot = try? PocketSlot(from: decoder)
        }
    }
}
