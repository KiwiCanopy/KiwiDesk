import CoreGraphics

/// A two-finger touch's running travel on the pad, in mm (#1873 ▸
/// Ruling 2026-11-16): what a long swipe's steps count after the
/// latch. A frame adds the mean move of the contacts it shares with
/// its device's previous frame, and only while exactly two are down
/// in both, so a finger landing or lifting adds nothing. The sum
/// accumulates for the reader's life, never reset; a reader takes
/// differences, and only between two readings of one `source`. Pure;
/// the touch reader runs it under its lock.
public struct TouchTravel: Sendable {
    /// One reading: the sum, and what it was counted on — the
    /// reader and the pad carrying the two fingers. A change of
    /// source between readings is no travel.
    public struct Reading: Equatable, Sendable {
        public var sum: CGVector
        public var source: Int

        public init(sum: CGVector, source: Int) {
            self.sum = sum
            self.source = source
        }
    }

    /// The reader this sum belongs to, folded into every source.
    let generation: Int
    /// The pad's axes: x right, y up.
    private(set) var sum = CGVector.zero
    private var last: [UInt: [Int32: CGPoint]] = [:]
    /// The pad that last carried exactly two fingers, and whether it
    /// reports its size.
    private var active: (device: UInt, sized: Bool)?

    init(generation: Int = 0) {
        self.generation = generation
    }

    /// The reading a long swipe counts in; nil until a pad carries
    /// two fingers, and while the one carrying them reports no size,
    /// where the steps count points.
    var reading: Reading? {
        guard let active, active.sized else { return nil }
        var hasher = Hasher()
        hasher.combine(generation)
        hasher.combine(active.device)
        return Reading(sum: sum, source: hasher.finalize())
    }

    /// Feeds one device's frame. `size` is that pad in mm; a pad
    /// with none adds nothing.
    mutating func feed(
        device: UInt,
        contacts: [TouchContact],
        size: CGSize?
    ) {
        let now = Dictionary(
            contacts.map {
                ($0.id, CGPoint(x: Double($0.x), y: Double($0.y)))
            },
            uniquingKeysWith: { first, _ in first }
        )
        defer { last[device] = now }
        if now.count == 2 { active = (device, size != nil) }
        guard let size, now.count == 2,
            let before = last[device], before.count == 2
        else { return }
        let shared = now.keys.filter { before[$0] != nil }
        guard shared.count == 2 else { return }
        var move = CGVector.zero
        for id in shared {
            guard let a = before[id], let b = now[id] else { continue }
            move.dx += (b.x - a.x) * size.width
            move.dy += (b.y - a.y) * size.height
        }
        sum.dx += move.dx / 2
        sum.dy += move.dy / 2
    }
}
