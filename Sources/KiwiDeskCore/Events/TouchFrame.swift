import Foundation

/// One finger on the trackpad, as one MultitouchSupport frame
/// reports it (#1873). Positions are normalized to the pad, 0…1,
/// with y growing UP.
public struct TouchContact: Equatable, Sendable {
    public var id: Int32
    public var x: Float
    public var y: Float

    public init(id: Int32, x: Float, y: Float) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// The Sendable snapshot the router is fed: the fingers touching
/// the pad, the modifiers held, and the frame's own clock.
public struct TouchFrame: Equatable, Sendable {
    public var time: Double
    public var contacts: [TouchContact]
    public var modifiers: ScrollChord

    public init(
        time: Double,
        contacts: [TouchContact],
        modifiers: ScrollChord = []
    ) {
        self.time = time
        self.contacts = contacts
        self.modifiers = modifiers
    }
}

extension TouchFrame {
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

    /// Reads `count` records from `buffer`; a record past the
    /// buffer's end is dropped, never read.
    static func contacts(
        in buffer: UnsafeRawBufferPointer,
        count: Int
    ) -> [TouchContact] {
        var out: [TouchContact] = []
        for index in 0..<max(count, 0) {
            let base = index * Layout.stride
            guard base + Layout.stride <= buffer.count else { break }
            let state = buffer.loadUnaligned(
                fromByteOffset: base + Layout.state,
                as: Int32.self
            )
            guard touchingStates.contains(state) else { continue }
            out.append(
                TouchContact(
                    id: buffer.loadUnaligned(
                        fromByteOffset: base + Layout.identifier,
                        as: Int32.self
                    ),
                    x: buffer.loadUnaligned(
                        fromByteOffset: base + Layout.x,
                        as: Float.self
                    ),
                    y: buffer.loadUnaligned(
                        fromByteOffset: base + Layout.y,
                        as: Float.self
                    )
                )
            )
        }
        return out
    }
}
