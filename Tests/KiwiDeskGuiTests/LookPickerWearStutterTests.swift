import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The wear's drop (#3700): the wear's own settings write repaints
/// no card under the overlay, the fall starts after the commit the
/// wear's call ran in, and the frame log counts what the screen
/// dropped. Main actor for the controller and its panel; the
/// driven test shows one panel, as `LookPickerPanelTests` does.
@Suite("Look picker wear stutter (#3700)", .serialized)
@MainActor
struct LookPickerWearStutterTests {
    @Test("the wear repaints no card and falls after its commit")
    func wearIsDriven() throws {
        let core = makeTestCore()
        let controller = LookPickerController(core: core)
        var later: [@MainActor () -> Void] = []
        var committed: [@MainActor () -> Void] = []
        controller.after = { _, work in later.append(work) }
        controller.afterCommit = { committed.append($0) }
        controller.reduceMotion = { true }
        controller.handBack.nextTurn = { $0() }
        controller.handBack.orderFrontKey = { $0.orderFrontRegardless() }
        controller.show()
        defer { controller.close() }
        let model = try #require(controller.model)
        let before = model.settings
        // Browsing, an outside change repaints the cards.
        var other = before
        other.kiwishelf.thickness = before.kiwishelf.thickness + 3
        controller.settingsChanged(other)
        #expect(model.settings == other)
        while model.selection == model.wornIndex {
            model.handle(.step(1), repeated: false)
        }
        model.wearSelected()
        #expect(model.phase == .wearing)
        // The test core arms no wallpaper: ready came in the call,
        // and the fall waits for the commit.
        #expect(committed.count == 1)
        #expect(!controller.revealing)
        var during = model.settings
        during.kiwishelf.thickness += 5
        controller.settingsChanged(during)
        #expect(model.settings != during, "the wear repaints nothing")
        committed.forEach { $0() }
        #expect(controller.revealing)
        // The cap's resume after it starts nothing a second time.
        later.forEach { $0() }
        #expect(committed.count == 1)
    }

    @Test("the close logs the wear's frames once")
    func closeLogsTheFrames() {
        let core = makeTestCore()
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        let controller = LookPickerController(core: core)
        let log = LookPickerFrameLog()
        log.record(at: 0, frame: 1.0 / 60)
        log.record(at: 1.0 / 60, frame: 1.0 / 60)
        controller.frameLog = log
        controller.close()
        controller.close()
        #expect(lines.filter { $0.hasPrefix("look picker wear:") }.count == 1)
        #expect(controller.frameLog == nil)
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
}
