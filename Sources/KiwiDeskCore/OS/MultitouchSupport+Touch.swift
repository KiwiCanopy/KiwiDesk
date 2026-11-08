import Foundation

extension MultitouchSupport {
    /// The byte layout of one `MTTouch` record: the stride, and
    /// the offsets of its identifier, its state and its normalized
    /// position. The framework publishes no header, so this is the
    /// layout the 2026-10-31 probe read (unmeasured past macOS 27).
    enum Layout {
        static let stride = 96
        static let identifier = 16
        static let state = 20
        static let x = 32
        static let y = 36
    }

    /// The states a finger is ON the pad in: make-touch, touching
    /// and break-touch. Hovering and lingering fingers do not
    /// count.
    static let touchingStates: ClosedRange<Int32> = 3...5

    /// Reads `count` records from `buffer`, which the caller sizes
    /// at `count` strides. A record whose position is not a finite
    /// point on or just past the pad is dropped: a layout a later
    /// macOS moved reads as garbage there, and garbage must never
    /// fire a slot. The margin keeps a finger at the border, whose
    /// reading may overshoot an edge (unmeasured).
    static func contacts(
        in buffer: UnsafeRawBufferPointer,
        count: Int
    ) -> [TouchContact] {
        var out: [TouchContact] = []
        for index in 0..<max(count, 0) {
            let base = index * Layout.stride
            guard base + Layout.stride <= buffer.count else { break }
            func read<T>(_ offset: Int, _ type: T.Type) -> T {
                buffer.loadUnaligned(fromByteOffset: base + offset, as: T.self)
            }
            guard touchingStates.contains(read(Layout.state, Int32.self))
            else { continue }
            let x = read(Layout.x, Float.self)
            let y = read(Layout.y, Float.self)
            guard onPad(x), onPad(y) else { continue }
            out.append(
                TouchContact(
                    id: read(Layout.identifier, Int32.self),
                    x: x,
                    y: y
                )
            )
        }
        return out
    }

    private static func onPad(_ value: Float) -> Bool {
        value.isFinite && (-0.1...1.1).contains(value)
    }
}
