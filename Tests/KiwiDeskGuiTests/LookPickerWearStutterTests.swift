import Foundation
import Testing

@testable import KiwiDesk

/// The wear's drop (#3700): the wear's own settings write repaints
/// no card under the overlay, the fall starts a turn after the
/// desk is ready, and the frame log counts what the screen dropped.
@Suite("Look picker wear stutter (#3700)")
@MainActor
struct LookPickerWearStutterTests {
    @Test("only a browsing picker repaints on a settings change")
    func wearRepaintsNothing() {
        typealias C = LookPickerController
        #expect(C.repaints(revealing: false, phase: .browsing))
        #expect(!C.repaints(revealing: false, phase: .wearing))
        #expect(!C.repaints(revealing: true, phase: .browsing))
    }

    @Test("a gap of three frames counts two dropped")
    func frameLogCounts() throws {
        let log = LookPickerFrameLog()
        let frame = 1.0 / 120
        for tick in [0.0, 1, 2, 5, 6] {
            log.record(at: tick * frame, frame: frame)
        }
        let line = try #require(log.stop())
        #expect(line.hasPrefix("look picker wear: 5 frames at 120 Hz"))
        #expect(line.contains("2 dropped"))
        #expect(line.contains("longest gap 25 ms"))
        #expect(LookPickerFrameLog().stop() == nil)
    }

    /// The controller's two doors take the fix: the repaint asks the
    /// verdict, and the ready resumes the fall a turn later.
    @Test("the controller takes the verdict and the deferred fall")
    func wiring() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/LookPicker")
        let read = { (name: String) throws -> String in
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
        }
        let controller = try read("LookPickerController.swift")
        #expect(
            controller.contains(
                "guardSelf.repaints(revealing:revealing,phase:model?.phase)"
            )
        )
        #expect(controller.contains("frameLog?.stop()"))
        let reveal = try read("LookPickerController+Reveal.swift")
        #expect(
            reveal.contains(
                "latch.fired=trueafter(0){[weakself]in"
                    + "guardletself,opening==currentelse{return}"
                    + "startReveal()}"
            )
        )
        #expect(reveal.contains("log.start(on:panel?.screen)"))
    }
}
