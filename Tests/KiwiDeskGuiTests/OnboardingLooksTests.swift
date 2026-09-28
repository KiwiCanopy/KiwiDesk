import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's looks step (#1720): a pick paints through Core's
/// door, the first one records what Revert returns to, a pick
/// that changes nothing and a step left untouched write nothing,
/// and an unsaved Settings draft — whose Save would overwrite a
/// paint — refuses every write.
@Suite("Onboarding looks step (#1720)")
@MainActor
struct OnboardingLooksTests {
    private final class Recorder {
        var live = TilingSettings()
        var paints: [(String?, String?)] = []
        var restores = 0
        var captures = 0
        var restoreLands = true
        var baselineLive = true
        var draftPending = false
    }

    private func look(_ name: String) throws -> ShelfLook {
        try #require(LookCatalog.bundled().first { $0.name == name })
    }

    private func makeModel(
        draftPending: Bool = false
    ) -> (OnboardingModel, Recorder, KiwiCore) {
        let model = OnboardingModel()
        let recorder = Recorder()
        let core = makeTestCore()
        model.tilingSettings = { recorder.live }
        model.shelfPalettes = { core.allPalettes }
        recorder.draftPending = draftPending
        model.settingsDraftPending = { recorder.draftPending }
        model.captureShelfBaseline = {
            recorder.captures += 1
            return core.shelfPaintBaseline()
        }
        model.onPaintShelf = { look, palette in
            recorder.paints.append((look?.name, palette?.name))
            if let look {
                look.apply(to: &recorder.live, palette: palette)
            } else {
                palette?.apply(to: &recorder.live)
            }
        }
        model.onRestoreShelf = { _ in
            recorder.restores += 1
            return recorder.restoreLands
        }
        model.baselineIsLive = { _ in recorder.baselineLive }
        model.beginPresentation(at: .looks)
        return (model, recorder, core)
    }

    private func palette(
        _ core: KiwiCore,
        _ name: String
    ) throws -> ColorPalette {
        try #require(core.allPalettes.first { $0.name == name })
    }

    @Test("a look paints with the palette it names")
    func lookCarriesItsPalette() throws {
        let (model, recorder, _) = makeModel()
        model.pickLook(try look("Taskbar"))
        #expect(recorder.paints.count == 1)
        #expect(recorder.paints.first?.0 == "Taskbar")
        #expect(recorder.paints.first?.1 == "Slate")
    }

    @Test("a palette paints the colours alone")
    func paletteAlone() throws {
        let (model, recorder, core) = makeModel()
        model.pickPalette(try palette(core, "Sunset"))
        #expect(recorder.paints.first?.0 == nil)
        #expect(recorder.paints.first?.1 == "Sunset")
    }

    @Test("only the first paint records the baseline")
    func baselineIsTheFirstPaints() throws {
        let (model, recorder, core) = makeModel()
        #expect(!model.hasLookChanges)
        model.pickLook(try look("Taskbar"))
        model.pickPalette(try palette(core, "Sunset"))
        #expect(recorder.captures == 1)
        #expect(model.hasLookChanges)
    }

    /// Glass and Kiwi (Default) are what a first run already
    /// shows, so picking them wakes neither the file nor Revert.
    @Test("a pick that changes nothing writes nothing")
    func noOpPickWritesNothing() throws {
        let (model, recorder, core) = makeModel()
        model.pickLook(try look(LookCatalog.defaultName))
        model.pickPalette(try palette(core, PaletteCatalog.defaultName))
        #expect(recorder.paints.isEmpty)
        #expect(recorder.captures == 0)
        #expect(!model.hasLookChanges)
    }

    @Test("revert restores the baseline once and clears it")
    func revertRestores() throws {
        let (model, recorder, _) = makeModel()
        model.pickLook(try look("Taskbar"))
        model.revertLooks()
        #expect(recorder.restores == 1)
        #expect(!model.hasLookChanges)
        model.revertLooks()
        #expect(recorder.restores == 1)
    }

    /// Refused because another profile went live: the baseline
    /// no longer describes it, so Revert greys and the next pick
    /// records a fresh one rather than keeping the stale one.
    @Test("a baseline of another profile is re-captured")
    func staleBaselineIsRecaptured() throws {
        let (model, recorder, core) = makeModel()
        model.pickLook(try look("Taskbar"))
        recorder.restoreLands = false
        recorder.baselineLive = false
        model.revertLooks()
        #expect(!model.hasLookChanges)
        model.pickPalette(try palette(core, "Sunset"))
        #expect(recorder.captures == 2)
    }

    @Test("a refused revert keeps its baseline")
    func refusedRevertKeepsBaseline() throws {
        let (model, recorder, _) = makeModel()
        model.pickLook(try look("Taskbar"))
        recorder.restoreLands = false
        model.revertLooks()
        #expect(model.hasLookChanges)
    }

    @Test("an untouched step writes nothing")
    func untouchedWritesNothing() {
        let (model, recorder, _) = makeModel()
        model.revertLooks()
        model.continueAfterLooks()
        #expect(recorder.paints.isEmpty)
        #expect(recorder.restores == 0)
        #expect(recorder.captures == 0)
    }

    @Test("an unsaved Settings draft refuses every write")
    func draftBlocks() throws {
        let (model, recorder, core) = makeModel(draftPending: true)
        model.pickLook(try look("Taskbar"))
        model.pickPalette(try palette(core, "Sunset"))
        #expect(recorder.paints.isEmpty)
        #expect(recorder.captures == 0)
        #expect(!model.hasLookChanges)
    }

    @Test("a draft opened after a pick refuses the revert")
    func draftBlocksRevert() throws {
        let (model, recorder, _) = makeModel()
        model.pickLook(try look("Taskbar"))
        recorder.draftPending = true
        model.revertLooks()
        #expect(recorder.restores == 0)
        #expect(model.hasLookChanges)
    }

    @Test("a new presentation starts without a baseline")
    func replayStartsClean() throws {
        let (model, _, _) = makeModel()
        model.pickLook(try look("Taskbar"))
        model.beginPresentation(at: .spaces)
        #expect(!model.hasLookChanges)
    }
}
