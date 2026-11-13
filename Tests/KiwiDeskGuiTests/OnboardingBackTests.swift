import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The tour's Back (#3288): drawn where the planned step before is
/// not the grant page, navigation only — picks, baselines and the
/// closing latch survive it — and a return to Spaces rests its
/// rows.
@Suite("Onboarding Back button (#3288)")
@MainActor
struct OnboardingBackTests {
    private func walk(
        _ model: OnboardingModel,
        to target: OnboardingModel.Step
    ) {
        var guardRail = OnboardingModel.Step.allCases.count
        while model.step != target, guardRail > 0 {
            guardRail -= 1
            model.advance()
        }
    }

    @Test("Back shows on Looks, Bars, Keys and Done, never earlier")
    func backShowsAfterSpaces() {
        let model = OnboardingModel()
        model.beginPresentation(at: .grant)
        var shown: [OnboardingModel.Step] = []
        for step in OnboardingModel.Step.allCases {
            walk(model, to: step)
            if model.back != nil { shown.append(step) }
        }
        #expect(shown == [.looks, .bars, .keys, .done])
        let replay = OnboardingModel()
        replay.beginPresentation(at: .spaces)
        #expect(replay.back == nil)
        replay.advance()
        #expect(replay.backStep == .spaces)
    }

    @Test("Back steps to the planned step before")
    func backStepsOnce() {
        let model = OnboardingModel()
        model.beginPresentation(at: .grant)
        walk(model, to: .done)
        model.goBack()
        #expect(model.step == .keys)
        model.goBack()
        model.goBack()
        model.goBack()
        #expect(model.step == .spaces)
        model.goBack()
        #expect(model.step == .spaces, "never back to the grant page")
    }

    @Test("a closing beat stays reached after Back")
    func reachedEndStaysLatched() {
        let model = OnboardingModel()
        model.beginPresentation(at: .spaces)
        walk(model, to: .keys)
        #expect(model.reachedEnd)
        model.goBack()
        #expect(model.step == .bars)
        #expect(model.reachedEnd)
    }

    @Test("re-entering Looks holds the bars revealed again")
    func looksReholdsReveal() {
        let model = OnboardingModel()
        var holds: [Bool] = []
        model.holdBarsRevealed = { holds.append($0) }
        model.beginPresentation(at: .spaces)
        model.advance()
        model.advance()
        model.goBack()
        #expect(model.step == .looks)
        #expect(holds.last == true)
    }

    @Test("a Looks pick and its baseline survive Back and return")
    func looksBaselineIsTheFirstPaint() throws {
        let model = OnboardingModel()
        let core = makeTestCore()
        var live = TilingSettings()
        var captures = 0
        model.tilingSettings = { live }
        model.captureShelfBaseline = {
            captures += 1
            return core.tourBaseline()
        }
        model.onPaintShelf = { look, palette in
            live = KiwiCore.painted(live, look: look, palette: palette)
        }
        model.beginPresentation(at: .spaces)
        model.advance()
        let taskbar = try #require(
            LookCatalog.bundled(sizes: []).first { $0.name == "Taskbar" }
        )
        model.pickLook(taskbar)
        #expect(model.hasLookChanges)
        model.goBack()
        model.advance()
        #expect(model.step == .looks)
        #expect(model.hasLookChanges, "Back is not undo")
        let palette = try #require(
            core.allPalettes.first { $0.name == "Sunset" }
        )
        model.pickPalette(palette)
        #expect(captures == 1, "no baseline taken on re-entry")
    }

    @Test("a Bars pick and its baseline survive Back and return")
    func barsBaselineSurvives() {
        let model = OnboardingModel()
        var visibility = TilingSettings().uniformBarVisibility
        var captures = 0
        model.bars.captureBaseline = {
            captures += 1
            return makeTestCore().tourBaseline()
        }
        model.bars.onSetVisibility = { picked in
            guard picked != visibility else { return false }
            visibility = picked
            return true
        }
        model.beginPresentation(at: .spaces)
        model.advance()
        model.advance()
        #expect(model.step == .bars)
        model.bars.pick(.hidden)
        #expect(model.bars.hasChanges)
        model.goBack()
        model.advance()
        #expect(model.step == .bars)
        #expect(model.bars.hasChanges, "Back is not undo")
        model.bars.pick(.auto)
        #expect(captures == 1, "no baseline taken on re-entry")
    }

    @Test("a return to Spaces rests its rows; a new tour plays them")
    func spacesPlayOnce() {
        let model = OnboardingModel()
        model.beginPresentation(at: .spaces)
        #expect(!model.spacesPlayed)
        model.advance()
        model.goBack()
        #expect(model.step == .spaces)
        #expect(model.spacesPlayed)
        model.beginPresentation(at: .spaces)
        #expect(!model.spacesPlayed)
    }

    /// Every page hands the one predicate to `OnboardingPage`, so
    /// no step decides for itself whether Back draws.
    @Test("every page takes Back from the model")
    func pagesTakeTheModelsBack() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Onboarding")
        let files = [
            "OnboardingView+Grant.swift",
            "OnboardingView+Spaces.swift",
            "OnboardingLooksStep.swift",
            "OnboardingBarsStep.swift",
            "OnboardingView+Keys.swift",
            "OnboardingView+Closing.swift",
        ]
        for file in files {
            let source = SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            #expect(source.contains("back: model.back"), "\(file)")
        }
        let page = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "OnboardingPage.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(page.contains("if let back {"))
        #expect(page.contains("if let hint { hintLine(hint) }"))
    }
}
