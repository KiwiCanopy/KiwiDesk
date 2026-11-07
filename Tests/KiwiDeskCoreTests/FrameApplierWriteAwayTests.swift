import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The door's own order, over a fake writer.
@Suite("FrameApplier.writeAway (#3048)")
@MainActor
struct FrameApplierWriteAwayTests {
    private let id = WindowID(5)
    private let pid: pid_t = 900_003
    private let frame = CGRect(x: 1, y: 2, width: 3, height: 4)

    private final class Log: @unchecked Sendable {
        var lines: [String] = []
    }

    private func applier(
        _ log: Log,
        names named: WindowID?
    ) -> FrameApplier {
        let applier = FrameApplier()
        applier.writer = FrameWriter(
            setFrame: { _, _ in log.lines.append("frame") },
            setPosition: { _, _ in log.lines.append("position") },
            writeEUI: { _, on in log.lines.append("eui \(on)") },
            windowID: { _ in
                log.lines.append("id")
                return named
            }
        )
        applier.enhancedUIAtRest = { _ in true }
        return applier
    }

    @Test("re-checks the id and writes inside the Enhanced UI hold")
    func writesInsideTheHold() async {
        let log = Log()
        let door = applier(log, names: id)
        let wrote = await withCheckedContinuation { done in
            door.writeAway(
                id,
                frame,
                AXUIElementCreateApplication(pid),
                pid
            ) { done.resume(returning: $0) }
        }
        #expect(wrote)
        #expect(log.lines == ["eui false", "id", "frame", "eui true"])
    }

    @Test("an element naming another window writes nothing")
    func staleWritesNothing() async {
        let log = Log()
        let door = applier(log, names: WindowID(6))
        let wrote = await withCheckedContinuation { done in
            door.writeAway(
                id,
                frame,
                AXUIElementCreateApplication(pid),
                pid
            ) { done.resume(returning: $0) }
        }
        #expect(!wrote)
        #expect(!log.lines.contains("frame"))
    }
}
