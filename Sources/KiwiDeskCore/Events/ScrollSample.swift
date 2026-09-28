import CoreGraphics

/// One scroll-wheel event, read off the tap thread into plain
/// values so the router stays pure (#1656, #1519).
public struct ScrollSample: Equatable, Sendable {
    /// The trackpad's finger phase (`CGScrollPhase`); `.none` on
    /// a wheel and on every momentum event.
    public enum Phase: Equatable, Sendable {
        case none, mayBegin, began, changed, ended, cancelled
    }

    /// The momentum phase that follows a lift
    /// (`CGMomentumScrollPhase`).
    public enum Momentum: Equatable, Sendable {
        case none, began, changed, ended
    }

    public var chord: ScrollChord
    /// Delta in points, in the NATURAL-scrolling convention
    /// whatever macOS's own setting says: the system inversion is
    /// undone here, so a consumer applies KiwiDesk's own toggle
    /// alone (#1656 ruling, Natural scrolling).
    public var delta: CGVector
    public var phase: Phase
    public var momentum: Momentum
    /// Global display coordinates, top-left origin (AX space).
    public var location: CGPoint

    public init(
        chord: ScrollChord,
        delta: CGVector,
        phase: Phase = .none,
        momentum: Momentum = .none,
        location: CGPoint = .zero
    ) {
        self.chord = chord
        self.delta = delta
        self.phase = phase
        self.momentum = momentum
        self.location = location
    }

    /// Builds a sample from the event's raw fields.
    /// `invertedBySystem` is `NSEvent.isDirectionInvertedFromDevice`
    /// — true while macOS's Natural scrolling is on, when the raw
    /// delta is already in the natural convention.
    public init(
        flags: CGEventFlags,
        pointDeltaX: Double,
        pointDeltaY: Double,
        invertedBySystem: Bool,
        scrollPhase: Int64,
        momentumPhase: Int64,
        location: CGPoint
    ) {
        let sign: Double = invertedBySystem ? 1 : -1
        self.init(
            chord: ScrollChord(flags: flags),
            delta: CGVector(
                dx: pointDeltaX * sign,
                dy: pointDeltaY * sign
            ),
            phase: Self.phase(scrollPhase),
            momentum: Self.momentum(momentumPhase),
            location: location
        )
    }

    /// `CGScrollPhase` raw values; an unknown value reads as none.
    static func phase(_ raw: Int64) -> Phase {
        switch raw {
        case 1: .began
        case 2: .changed
        case 4: .ended
        case 8: .cancelled
        case 128: .mayBegin
        default: .none
        }
    }

    /// `CGMomentumScrollPhase` raw values.
    static func momentum(_ raw: Int64) -> Momentum {
        switch raw {
        case 1: .began
        case 2: .changed
        case 3: .ended
        default: .none
        }
    }
}
