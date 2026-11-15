import CoreGraphics

/// A two-finger touch's running travel on the pad, in mm (#1873 ▸
/// Ruling 2026-11-16): what a long swipe's steps count after the
/// latch. A frame adds the mean move of the contacts it shares with
/// its device's previous frame, and only while exactly two are down
/// in both, so a finger landing or lifting adds nothing. The sum is
/// monotonic in time, never reset; a reader takes differences. Pure;
/// the touch reader runs it under its lock.
struct TouchTravel: Equatable, Sendable {
    /// The pad's axes: x right, y up.
    private(set) var sum = CGVector.zero
    private var last: [UInt: [Int32: CGPoint]] = [:]

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
