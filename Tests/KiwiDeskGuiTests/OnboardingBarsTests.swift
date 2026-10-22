import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's bars step (#2515): a pick goes through Core's door,
/// the first one records what Revert returns to, a pick that
/// changes nothing and a step left untouched write nothing, an
/// unsaved Settings draft refuses every write, and only the looks
/// step holds the bars shown.
@Suite("Onboarding bars step (#2515)")
@MainActor
struct OnboardingBarsTests {
    private final class Recorder {
        var live = TilingSettings()
        var picks: [ShelfVisibility] = []
        var restores = 0
        var captures = 0
        var restoreLands = true
        var baselineLive = true
        var draftPending = false
        var holds: [Bool] = []
    }

    private func makeModel(
        draftPending: Bool = false
    ) -> (OnboardingModel, Recorder) {
        let model = OnboardingModel()
        let recorder = Recorder()
        let core = makeTestCore()
        recorder.live.setEveryBarVisibility(.auto)
        recorder.draftPending = draftPending
        let bars = model.bars
        bars.tilingSettings = { recorder.live }
        bars.settingsDraftPending = { recorder.draftPending }
        bars.captureBaseline = {
            recorder.captures += 1
            return core.shelfPaintBaseline()
        }
        bars.onSetVisibility = { visibility in
            recorder.picks.append(visibility)
            recorder.live.setEveryBarVisibility(visibility)
        }
        bars.onRestore = { _ in
            recorder.restores += 1
            return recorder.restoreLands
        }
        bars.baselineIsLive = { _ in recorder.baselineLive }
        model.holdBarsRevealed = { recorder.holds.append($0) }
        model.beginPresentation(at: .bars)
        return (model, recorder)
    }

    @Test("a pick sets every bar and marks its tile")
    func pickSetsVisibility() {
        let (model, recorder) = makeModel()
        #expect(model.bars.selected == .auto)
        model.bars.pick(.hidden)
        #expect(recorder.picks == [.hidden])
        #expect(model.bars.selected == .hidden)
        #expect(model.bars.hasChanges)
    }

    /// Bars that differ — a replay over a setup the user split in
    /// Settings — mark no tile.
    @Test("bars that differ select no tile")
    func mixedSelectsNothing() {
        let (model, recorder) = makeModel()
        recorder.live.spaceBarStyle.visibility = .always
        model.bars.refresh()
        #expect(model.bars.selected == nil)
    }

    @Test("a pick that changes nothing writes nothing")
    func noOpPickWritesNothing() {
        let (model, recorder) = makeModel()
        model.bars.pick(.auto)
        #expect(recorder.picks.isEmpty)
        #expect(recorder.captures == 0)
        #expect(!model.bars.hasChanges)
    }

    @Test("only the first pick records the baseline")
    func baselineIsTheFirstPicks() {
        let (model, recorder) = makeModel()
        model.bars.pick(.hidden)
        model.bars.pick(.always)
        #expect(recorder.captures == 1)
    }

    @Test("revert restores the baseline once and clears it")
    func revertRestores() {
        let (model, recorder) = makeModel()
        model.bars.pick(.hidden)
        model.bars.revert()
        #expect(recorder.restores == 1)
        #expect(!model.bars.hasChanges)
        model.bars.revert()
        #expect(recorder.restores == 1)
    }

    @Test("a refused revert keeps its baseline")
    func refusedRevertKeepsBaseline() {
        let (model, recorder) = makeModel()
        model.bars.pick(.hidden)
        recorder.restoreLands = false
        model.bars.revert()
        #expect(model.bars.hasChanges)
    }

    @Test("a baseline of another profile is re-captured")
    func staleBaselineIsRecaptured() {
        let (model, recorder) = makeModel()
        model.bars.pick(.hidden)
        recorder.baselineLive = false
        #expect(!model.bars.hasChanges)
        model.bars.pick(.always)
        #expect(recorder.captures == 2)
    }

    @Test("an untouched step writes nothing")
    func untouchedWritesNothing() {
        let (model, recorder) = makeModel()
        model.bars.revert()
        model.continueAfterBars()
        #expect(recorder.picks.isEmpty)
        #expect(recorder.restores == 0)
        #expect(recorder.captures == 0)
    }

    @Test("an unsaved Settings draft refuses every write")
    func draftBlocks() {
        let (model, recorder) = makeModel(draftPending: true)
        #expect(model.bars.blocked)
        model.bars.pick(.hidden)
        #expect(recorder.picks.isEmpty)
        #expect(recorder.captures == 0)
    }

    @Test("a draft opened after a pick refuses the revert")
    func draftBlocksRevert() {
        let (model, recorder) = makeModel()
        model.bars.pick(.hidden)
        recorder.draftPending = true
        model.bars.revert()
        #expect(recorder.restores == 0)
    }

    @Test("a new presentation starts without a baseline")
    func replayStartsClean() {
        let (model, _) = makeModel()
        model.bars.pick(.hidden)
        model.beginPresentation(at: .spaces)
        #expect(!model.bars.hasChanges)
    }

    /// The looks step paints bars the user must see; the bars
    /// step must show them as the pick leaves them, so the hold
    /// is the looks step's alone and every other step releases it.
    @Test("only the looks step holds the bars shown")
    func onlyLooksHolds() {
        let (model, recorder) = makeModel()
        model.beginPresentation(at: .spaces)
        model.continueAfterSpaces()
        #expect(recorder.holds.last == true)
        model.continueAfterLooks()
        #expect(model.step == .bars)
        #expect(recorder.holds.last == false)
        model.continueAfterBars()
        #expect(recorder.holds.last == false)
    }
}
