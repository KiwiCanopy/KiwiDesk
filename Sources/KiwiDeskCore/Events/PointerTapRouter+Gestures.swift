import CoreGraphics
import Foundation

/// One of macOS's gesture events as the pointer tap reads it
/// (#1873): a gesture (CG type 29) or a Dock stream (type 30), from
/// private event fields measured on macOS 27.2 (probes,
/// 2026-11-14). An OS that moves them reads zeros, so no stream
/// opens and every gesture passes, the fallback being no consume.
struct GestureEventSample: Equatable, Sendable {
    /// Field 110: on type 29, 8 a magnification and 5 a rotation,
    /// with 0, 4 and 6 the touch frames, translation and scroll
    /// beside them; on type 30, 23.
    var subtype: Int
    /// Field 132: 1 began, 2 changed, 4 ended, 8 cancelled.
    var phase: Int
    /// On type 29, field 113: the step's magnification, or its
    /// degrees of rotation. On type 30, field 124: the stream's
    /// progress so far, negative for a four-finger pinch together.
    var value: Double
    /// Type 30, the Dock's stream.
    var dock = false
    /// Field 123 on a Dock stream: 1 horizontal, 2 vertical, 3 a
    /// four-finger pinch or spread.
    var axis = 0
    /// The fingers the touch reader saw at this event, 0 for none
    /// read (`TouchFingerCount`).
    var fingers = 0

    static let magnify = 8
    static let rotation = 5
    static let horizontal = 1
    static let vertical = 2
    static let dockPinch = 3

    var began: Bool { phase == 1 }
    var ended: Bool { phase == 4 || phase == 8 }
}

/// A magnification or rotation the tap took at its begin, held to
/// its end: every event of the touch carrying its keys is swallowed
/// meanwhile, so the app under the pointer sees none of it.
struct GestureEventStream: Equatable, Sendable {
    var chord: ScrollChord
    /// The subtypes begun and not yet ended.
    var open: Set<Int>
    var magnified = 0.0
    var rotated = 0.0
    /// A Dock stream, held whole from its begin to its end.
    var dock = false
    /// Which inputs this stream has fired: one step each.
    var fired: Set<GestureInput> = []
    var lastEvent: CFAbsoluteTime
}

/// The gesture events' half of the router (#1873). Pure: the
/// decision reads the event and the snapshot. A stream fires one
/// discrete step per input, never a pan (#1656), once its sum
/// crosses the threshold.
extension PointerTapRouter {
    /// Summed magnification a pinch or spread fires at. Measured
    /// 2026-11-14: deliberate pinches summed 0.65–1.36, the
    /// magnification beside a rotation under 0.13.
    static let magnifyStep = 0.3
    /// Degrees a rotation fires at. Deliberate rotations summed
    /// 6–18°, the rotation beside a pinch under 2°.
    static let rotateStep = 5.0
    /// A four-finger pinch or spread's progress it fires at.
    /// Deliberate ones ended at 0.40–1.55 (probe v6, 2026-11-14).
    static let dockPinchStep = 0.3
    /// An open stream with no event for this long lost its end.
    static let streamLapse: CFAbsoluteTime = 1
    /// A Dock stream's lapse is longer: fingers held still may send
    /// nothing, and a stream dropped mid-way hands the Dock a part.
    /// A new begin ends a stream whose end was lost sooner.
    static let dockStreamLapse: CFAbsoluteTime = 10

    mutating func routingGesture(
        _ g: GestureEventSample,
        _ chord: ScrollChord,
        now: CFAbsoluteTime
    ) -> Routed {
        if let stream = gestureStream,
            now - stream.lastEvent
                > (stream.dock ? Self.dockStreamLapse : Self.streamLapse)
        {
            gestureStream = nil
        }
        guard let settings = snapshot.gestures else {
            gestureStream = nil
            return .pass
        }
        if g.dock || gestureStream?.dock == true {
            return routingDock(g, chord, settings, now: now)
        }
        let owned =
            g.subtype == GestureEventSample.magnify
            || g.subtype == GestureEventSample.rotation
        guard var stream = gestureStream else {
            guard owned, g.began, settings.claims(g.subtype, chord)
            else { return .pass }
            gestureStream = GestureEventStream(
                chord: chord,
                open: [g.subtype],
                lastEvent: now
            )
            return Routed(swallow: true, grab: [])
        }
        stream.lastEvent = now
        guard owned else {
            // A companion frame: the stream's while its keys hold.
            gestureStream = stream
            return Routed(swallow: chord == stream.chord, grab: [])
        }
        if g.began {
            stream.open.insert(g.subtype)
        } else if !stream.open.contains(g.subtype) {
            // Begun before the stream: its begin reached the app, so
            // the rest of it does too.
            gestureStream = stream
            return .pass
        }
        var fires: [TrackpadGestureEvent] = []
        if g.subtype == GestureEventSample.magnify {
            stream.magnified += g.value
            if abs(stream.magnified) >= Self.magnifyStep {
                let input: GestureInput =
                    stream.magnified > 0 ? .spread : .pinchTogether
                fires += firing(input, &stream, settings, now)
            }
        } else {
            stream.rotated += g.value
            if abs(stream.rotated) >= Self.rotateStep {
                fires += firing(.rotate, &stream, settings, now)
            }
        }
        if g.ended { stream.open.remove(g.subtype) }
        gestureStream = stream.open.isEmpty ? nil : stream
        return Routed(swallow: true, grab: [], gestures: fires)
    }

    /// A Dock stream is taken only at its begin and then whole to
    /// its end, whatever the keys do: a part of one reaching the
    /// Dock leaves it mid-gesture. The type-29 frames carrying its
    /// keys are its too while it runs.
    private mutating func routingDock(
        _ g: GestureEventSample,
        _ chord: ScrollChord,
        _ settings: GestureEventSettings,
        now: CFAbsoluteTime
    ) -> Routed {
        // A Dock event inside a pinch or rotation is the Dock's.
        if gestureStream?.dock == false { return .pass }
        // A begin while one runs: the old stream lost its end.
        if g.dock, g.began { gestureStream = nil }
        guard var stream = gestureStream else {
            guard g.dock, g.began,
                settings.claimsDock(g.axis, chord, fingers: g.fingers)
            else { return .pass }
            gestureStream = GestureEventStream(
                chord: chord,
                open: [g.subtype],
                dock: true,
                lastEvent: now
            )
            return Routed(swallow: true, grab: [])
        }
        // Touch frames run while fingers rest: only the Dock's own
        // events keep its stream alive.
        guard g.dock else {
            return Routed(swallow: chord == stream.chord, grab: [])
        }
        stream.lastEvent = now
        var fires: [TrackpadGestureEvent] = []
        if g.axis == GestureEventSample.dockPinch,
            abs(g.value) >= Self.dockPinchStep
        {
            let input: GestureInput =
                g.value > 0 ? .spread4 : .pinchTogether4
            fires = firing(input, &stream, settings, now)
        }
        gestureStream = g.ended ? nil : stream
        return Routed(swallow: true, grab: [], gestures: fires)
    }

    /// `input`'s one step for this stream, if its keys bind it.
    private func firing(
        _ input: GestureInput,
        _ stream: inout GestureEventStream,
        _ settings: GestureEventSettings,
        _ now: CFAbsoluteTime
    ) -> [TrackpadGestureEvent] {
        guard !stream.fired.contains(input) else { return [] }
        stream.fired.insert(input)
        guard settings.binds(input, stream.chord) else { return [] }
        return [
            TrackpadGestureEvent(
                kind: .gesture(input),
                fingers: 2,
                modifiers: stream.chord,
                time: now
            )
        ]
    }
}
