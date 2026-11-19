import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The boxed-in offer in Settings (#2756): its words, the answer
/// remembered per arrangement, and the Mac Checklist row it adds
/// while open.
@MainActor
@Suite("Screen shift offer", .serialized)
struct ScreenShiftOfferTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    private func screen(
        _ id: String,
        _ name: String,
        _ frame: CGRect,
        main: Bool = false
    ) -> ArrangedScreen {
        ArrangedScreen(id: id, name: name, frame: frame, isMain: main)
    }

    /// The preview's desk: a laptop between two taller screens.
    private var desk: [ArrangedScreen] {
        [
            screen(
                "lg",
                "LG HDR 4K",
                CGRect(x: -2560, y: -100, width: 2560, height: 1440)
            ),
            screen(
                "laptop",
                "Built-in Retina Display",
                CGRect(x: 0, y: 0, width: 1728, height: 1117),
                main: true
            ),
            screen(
                "dell",
                "DELL U2720Q",
                CGRect(x: 1728, y: -159, width: 2560, height: 1440)
            ),
        ]
    }

    @Test("the row and the alert say what the owner approved")
    func wording() throws {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        model.refreshScreenOffer(desk)
        let state = model.screenShift
        let offer = try #require(state.openOffer)
        let boxed = try #require(offer.boxed.first)
        #expect(
            ScreenShiftText.title(boxed, in: state)
                == "On Built-in Retina Display, windows from the "
                + "Spaces you aren't on show on DELL U2720Q"
        )
        #expect(
            ScreenShiftText.cause(boxed, in: state)
                == "KiwiDesk tucks them into a bottom corner, but LG "
                + "HDR 4K sits at the left one and DELL U2720Q at the "
                + "right one."
        )
        #expect(ScreenShiftText.button(offer) == "Shift Screen…")
        #expect(
            ScreenShiftText.alertTitle(offer, in: state)
                == "Shift DELL U2720Q up 212 pt in your macOS screen "
                + "arrangement?"
        )
        #expect(
            ScreenShiftText.alertMessage(offer, in: state)
                == "Between DELL U2720Q and Built-in Retina Display, "
                + "the pointer will cross 212 pt further down on DELL "
                + "U2720Q and further up on Built-in Retina Display than "
                + "it does now."
        )
    }

    @Test(
        "each direction says where the pointer lands",
        arguments: [
            (CGVector(dx: 0, dy: 9), "further up on A and further down on B"),
            (
                CGVector(dx: -9, dy: 0),
                "further right on A and further left on B"
            ),
            (
                CGVector(dx: 9, dy: 0),
                "further left on A and further right on B"
            ),
        ]
    )
    func crossingDirections(_ along: CGVector, _ words: String) {
        pinEnglish()
        defer { reset() }
        var state = ScreenShiftState()
        state.screens = [
            screen("a", "A", CGRect(x: 0, y: 0, width: 10, height: 10)),
            screen("b", "B", CGRect(x: 10, y: 0, width: 10, height: 10)),
        ]
        let offer = ScreenOffer(
            boxed: [],
            shifts: [
                ScreenShift(
                    screen: "a",
                    delta: along,
                    crossings: [ScreenCrossing(screen: "b", delta: along)]
                )
            ]
        )
        #expect(
            ScreenShiftText.alertMessage(offer, in: state).contains(words)
        )
    }

    @Test("identical screens carry their position")
    func identicalNames() {
        pinEnglish()
        defer { reset() }
        let twins = [
            screen("a", "DELL", CGRect(x: -100, y: 0, width: 100, height: 90)),
            screen("b", "DELL", CGRect(x: 100, y: 0, width: 100, height: 90)),
            screen("c", "Mac", CGRect(x: 0, y: 0, width: 100, height: 80)),
        ]
        var state = ScreenShiftState()
        state.screens = twins
        #expect(state.name(of: "a") == "DELL (left)")
        #expect(state.name(of: "b") == "DELL (right)")
        #expect(state.name(of: "c") == "Mac")
    }

    /// macOS numbers identical screens' names itself (#3496).
    @Test("numbered twins read by position, from the bare name")
    func numberedTwins() {
        pinEnglish()
        defer { reset() }
        var state = ScreenShiftState()
        state.screens = [
            screen("a", "Twin (2)", CGRect(x: 0, y: 0, width: 90, height: 90)),
            screen(
                "b",
                "Twin (1)",
                CGRect(x: 90, y: 0, width: 90, height: 90)
            ),
            screen("c", "Mac (2)", CGRect(x: 0, y: 90, width: 90, height: 80)),
        ]
        #expect(state.name(of: "a") == "Twin (left)")
        #expect(state.name(of: "b") == "Twin (right)")
        #expect(state.name(of: "c") == "Mac (2)")
    }

    @Test("a no is remembered for this arrangement only")
    func keptPerArrangement() {
        let model = makeTestModel()
        model.refreshScreenOffer(desk)
        #expect(model.screenShift.answer == nil)
        #expect(model.screenShiftChecklistDone == false)
        model.keepArrangement()
        #expect(model.screenShift.answer == .kept)
        #expect(model.screenShiftChecklistDone == true)
        // A changed arrangement asks again.
        var moved = desk
        moved[0].frame.origin.y += 10
        model.refreshScreenOffer(moved)
        #expect(model.screenShift.answer == nil)
        model.refreshScreenOffer(desk)
        #expect(model.screenShift.answer == .kept)
    }

    @Test("the checklist counts the row only while it shows")
    func checklistCount() {
        let model = makeTestModel()
        model.refreshMacChecklist()
        let total = model.macChecklistTotal
        let done = model.macChecklistDone
        #expect(total == MacChecklistProgress.total)
        model.refreshScreenOffer(desk)
        #expect(model.macChecklistTotal == total + 1)
        #expect(model.macChecklistDone == done)
        model.keepArrangement()
        #expect(model.macChecklistDone == done + 1)
        model.refreshScreenOffer([])
        #expect(model.macChecklistTotal == total)
    }

    @Test("a screen change closes the alert unanswered")
    func staleAlertCloses() throws {
        let model = makeTestModel()
        model.refreshScreenOffer(desk)
        let offer = try #require(model.screenShift.openOffer)
        model.askScreenShift(offer)
        model.refreshScreenOffer(desk)
        #expect(model.screenShift.asking == offer)
        var moved = desk
        moved[2].frame.origin.y -= 20
        model.refreshScreenOffer(moved)
        #expect(model.screenShift.asking == nil)
    }

    @Test("Shift writes the moves and files the yes")
    func shiftWritesAndFiles() throws {
        let model = makeTestModel()
        let core = model.core
        let start = CGRect(x: 1728, y: -159, width: 2560, height: 1440)
        var bounds = start
        core.state.workspaces.displays[DisplayID(3)] = Display(
            id: DisplayID(3),
            name: "DELL U2720Q",
            frame: start
        )
        core.tiler.displayFrames = { [(DisplayID(3), start)] }
        core.tiler.readArrangement = { _ in
            [
                DisplayReading(
                    id: DisplayID(3),
                    uuid: "dell",
                    bounds: bounds,
                    isMain: false
                )
            ]
        }
        var written: [DisplayID: CGPoint] = [:]
        core.tiler.writeArrangement = {
            written = $0
            if let origin = $0[DisplayID(3)] { bounds.origin = origin }
            return true
        }
        model.refreshScreenOffer(desk)
        let offer = try #require(model.screenShift.openOffer)
        model.askScreenShift(offer)
        model.applyScreenShift(offer)
        #expect(written == [DisplayID(3): CGPoint(x: 1728, y: -371)])
        #expect(model.screenShift.asking == nil)
        // Filed under the arrangement the yes produced.
        #expect(
            model.screenShift.answers["dell@1728,-371,2560x1440"]
                == "shifted:dell"
        )
    }

    @Test("Simple lists the open offer, and not once kept")
    func simpleListsTheOffer() {
        let model = makeTestModel()
        model.refreshScreenOffer(desk)
        #expect(SimpleMacChecklist.openRows(model).contains(.parkCorners))
        model.keepArrangement()
        #expect(!SimpleMacChecklist.openRows(model).contains(.parkCorners))
        model.refreshScreenOffer([])
        #expect(SimpleMacChecklist.openConditional(model).isEmpty)
    }

    @Test("an answer survives its store")
    func answerRoundTrip() {
        let shifted = ScreenShiftAnswer.shifted(["a", "b"])
        #expect(ScreenShiftAnswer(shifted.stored) == shifted)
        #expect(ScreenShiftAnswer("kept") == .kept)
        #expect(ScreenShiftAnswer("other") == nil)
    }
}
