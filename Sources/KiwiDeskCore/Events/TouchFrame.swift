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
