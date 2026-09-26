import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// How a starter setup's layouts are tuned for the hardware —
/// the per-class census of `StarterTuning.settings(mainShape:)`.
///
/// Split from `StarterSetupSeedTests`, which owns the generator,
/// the preset face and the first-run seed: adding the Scrolling
/// slot's row (#1018) took that file past the 350-line ceiling,
/// and `.claude/rules/tests.md` says to split before rather than
/// after. Pure over a `ScreenClass`, so unlike its parent this
/// suite needs no core, no displays and no serialization.
@Suite("Starter tuning per screen class")
struct StarterTuningTests {
    @Test("tuning follows the MAIN screen's class")
    func tuningFollowsMainScreen() {
        let settings = StarterTuning.settings(mainShape: .desktop)
        #expect(settings.stack.masterRatio == 0.8)
        #expect(settings.track.newWindow == .ownTrack)
        // At 2560 pt a three-column grid gives 850 pt cells.
        #expect(settings.grid.columns == 2)
        #expect(settings.grid.rows == 2)
        // A laptop tightens the gaps; its bars keep the one
        // default (#1359, `BarThicknessDefaultTests`).
        let small = StarterTuning.settings(mainShape: .laptop)
        #expect(small.gapsGlobal == .uniform(6))
        // Everything that assumes width has to flip.
        let tall = StarterTuning.settings(mainShape: .pivoted)
        #expect(tall.stack.stackPosition == .bottom)
        #expect(tall.scrolling.orientation == .vertical)
        #expect(tall.grid.splitDirection == .vertical)
        // One master on a 3440 pt screen is an absurd pane.
        let wide = StarterTuning.settings(mainShape: .ultrawide)
        #expect(wide.stack.masterCount == 2)
        #expect(wide.track.autoTracks)
        #expect(wide.minWindowSize == 420)
        // The Scrolling slot is the one tuning value that
        // shipped without a row here (#1018): `.auto` resolves
        // near-full, which is the "my windows were squashed into
        // one" picture the starter lead exists to avoid, so the
        // base must be explicit and the ultrawide must differ.
        // Bound to the constants, or the two halves below are
        // asserting about numbers no production path reaches:
        // rewriting `base()` to `.fraction(clamping: 0.9)` left
        // every one of these green (code review, 2026-08-26).
        #expect(
            settings.scrolling.slotSize
                == .fraction(clamping: StarterTuning.standardSlot)
        )
        #expect(
            wide.scrolling.slotSize
                == .fraction(clamping: StarterTuning.ultrawideSlot)
        )
        #expect(settings.scrolling.slotSize != .auto)
        #expect(wide.scrolling.slotSize != settings.scrolling.slotSize)
        // Derived, not restated: pinning the fraction would move
        // the copy rather than guard it. What the standard slot
        // has to MEAN is `StarterSlotSettingsFitTests`' (#1662);
        // here, that the ultrawide column comes out narrower IN
        // POINTS than the standard one does on a 27", which is the
        // whole reason it differs.
        #expect(
            StarterTuning.ultrawideSlot * 3440
                < StarterTuning.standardSlot * 2560
        )
    }
}
