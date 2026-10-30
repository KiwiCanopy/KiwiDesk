import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `kiwishelf.set_reading_contrast` (#2569): the user's floor feeds
/// every reading fade — the peek's Fill, KiwiHub's and the cue
/// plates' Fill and KiwiHub's highlight share — clamped to
/// `readingContrastRange`, raised to the increased floor under
/// Increase Contrast and never lowered by it.
@Suite("Reading contrast override (#2569)")
struct ReadingContrastTests {
    /// The default look at the strongest fade.
    private func shelf(_ contrast: Double) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.fillFade = 100
        shelf.readingContrast = contrast
        return shelf
    }

    @Test("The default is the reading floor")
    func defaultIsTheFloor() {
        #expect(KiwiShelf().readingContrast == KiwiShelf.readingInkFloor)
        #expect(
            KiwiShelf().readingFloor(increaseContrast: true)
                == KiwiShelf.increasedReadingInkFloor
        )
    }

    /// 1 is no floor: the full fade. Past what the Fill can reach,
    /// it paints flat.
    @Test("The override moves every reading fade")
    func overrideFeedsEveryFade() {
        let none = shelf(1)
        let base = shelf(KiwiShelf.readingInkFloor)
        let flat = shelf(4.5)
        for read in [
            { (s: KiwiShelf) in s.readingGlassFill(increaseContrast: false) },
            { (s: KiwiShelf) in s.panelGlassFill(increaseContrast: false) },
        ] {
            #expect(read(none).minShare < 0.001)
            #expect(read(base).minShare > 0)
            #expect(read(base).minShare < 1)
            #expect(read(flat).minShare == 1)
        }
        let low = none.highlightFadeShare(increaseContrast: false)
        let high = flat.highlightFadeShare(increaseContrast: false)
        #expect(low < high)
    }

    @Test("Increase Contrast raises the floor, never lowers it")
    func increaseContrastWinsUpward() {
        #expect(
            shelf(1).readingFloor(increaseContrast: true)
                == KiwiShelf.increasedReadingInkFloor
        )
        #expect(shelf(4).readingFloor(increaseContrast: true) == 4)
        #expect(shelf(1).readingFloor(increaseContrast: false) == 1)
        #expect(
            shelf(1).panelGlassFill(increaseContrast: true).minShare
                == shelf(KiwiShelf.readingInkFloor)
                .panelGlassFill(increaseContrast: true).minShare
        )
    }

    @Test("The verb clamps to its range")
    func verbClamps() throws {
        for (value, expected) in [(0.2, 1.0), (9.0, 4.5), (3.0, 3.0)] {
            var shelf = KiwiShelf()
            try KiwiShelfCommandSetting.parse(
                field: "reading_contrast",
                args: [.number(value)]
            ).get().apply(to: &shelf)
            #expect(shelf.readingContrast == expected)
        }
        #expect(
            (try? KiwiShelfCommandSetting.parse(
                field: "reading_contrast",
                args: [.string("high")]
            ).get()) == nil
        )
    }

    /// The verb a user types reaches the live settings, the store
    /// the reading fades read.
    @Test("The command reaches the live settings")
    @MainActor
    func commandReachesSettings() {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwidesk-tests-\(UUID().uuidString)")
        )
        #expect(
            core.execute(
                "kiwishelf.set_reading_contrast",
                args: [.number(3)]
            ).isSuccess
        )
        #expect(core.tiler.settings.kiwishelf.readingContrast == 3)
    }

    @Test("A stored value decodes clamped")
    func decodeClamps() throws {
        let shelf = try JSONDecoder().decode(
            KiwiShelf.self,
            from: Data(#"{"reading_contrast": 0}"#.utf8)
        )
        #expect(shelf.readingContrast == 1)
    }
}
