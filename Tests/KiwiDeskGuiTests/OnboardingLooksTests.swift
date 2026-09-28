import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's looks step (#1720): a pick paints through Core's
/// door, the first one records what Revert returns to, a step
/// left untouched writes nothing, and an unsaved Settings draft —
/// whose Save would overwrite a paint — refuses every write.
@Suite("Onboarding looks step (#1720)")
@MainActor
struct OnboardingLooksTests {
    private final class Recorder {
        var paints: [(String?, String?)] = []
        var restores: [KiwiCore.ShelfPaintBaseline] = []
        var captures = 0
    }

    private let taskbar = ShelfLook(
        name: "Taskbar",
        palette: "Slate",
        style: [:]
    )
    private let slate = ColorPalette(name: "Slate", colors: [:])
    private let sunset = ColorPalette(name: "Sunset", colors: [:])

    private func makeModel(
        draftPending: Bool = false
    ) -> (OnboardingModel, Recorder) {
        let model = OnboardingModel()
        let recorder = Recorder()
        let core = makeTestCore()
        model.shelfPalettes = { [slate, sunset] }
        model.settingsDraftPending = { draftPending }
        model.captureShelfBaseline = {
            recorder.captures += 1
            return core.shelfPaintBaseline()
        }
        model.onPaintShelf = { look, palette in
            recorder.paints.append((look?.name, palette?.name))
        }
        model.onRestoreShelf = { recorder.restores.append($0) }
        model.beginPresentation(at: .looks)
        return (model, recorder)
    }

    @Test("a look paints with the palette it names")
    func lookCarriesItsPalette() {
        let (model, recorder) = makeModel()
        model.pickLook(taskbar)
        #expect(recorder.paints.count == 1)
        #expect(recorder.paints.first?.0 == "Taskbar")
        #expect(recorder.paints.first?.1 == "Slate")
    }

    @Test("a palette paints the colours alone")
    func paletteAlone() {
        let (model, recorder) = makeModel()
        model.pickPalette(sunset)
        #expect(recorder.paints.first?.0 == nil)
        #expect(recorder.paints.first?.1 == "Sunset")
    }

    @Test("only the first paint records the baseline")
    func baselineIsTheFirstPaints() {
        let (model, recorder) = makeModel()
        #expect(!model.hasLookChanges)
        model.pickLook(taskbar)
        model.pickPalette(sunset)
        #expect(recorder.captures == 1)
        #expect(model.hasLookChanges)
    }

    @Test("revert restores the baseline once and clears it")
    func revertRestores() {
        let (model, recorder) = makeModel()
        model.pickLook(taskbar)
        model.revertLooks()
        #expect(recorder.restores.count == 1)
        #expect(!model.hasLookChanges)
        model.revertLooks()
        #expect(recorder.restores.count == 1)
    }

    @Test("an untouched step writes nothing")
    func untouchedWritesNothing() {
        let (model, recorder) = makeModel()
        model.revertLooks()
        model.continueAfterLooks()
        #expect(recorder.paints.isEmpty)
        #expect(recorder.restores.isEmpty)
        #expect(recorder.captures == 0)
    }

    @Test("an unsaved Settings draft refuses every write")
    func draftBlocks() {
        let (model, recorder) = makeModel(draftPending: true)
        model.pickLook(taskbar)
        model.pickPalette(sunset)
        #expect(recorder.paints.isEmpty)
        #expect(recorder.captures == 0)
        #expect(!model.hasLookChanges)
    }

    @Test("a new presentation starts without a baseline")
    func replayStartsClean() {
        let (model, _) = makeModel()
        model.pickLook(taskbar)
        model.beginPresentation(at: .spaces)
        #expect(!model.hasLookChanges)
    }
}
