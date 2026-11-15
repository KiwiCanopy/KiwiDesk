import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

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
                == "The pointer will then enter DELL U2720Q 212 pt "
                + "lower than now, and Built-in Retina Display 212 pt "
                + "higher."
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

    @Test("an answer survives its store")
    func answerRoundTrip() {
        let shifted = ScreenShiftAnswer.shifted(["a", "b"])
        #expect(ScreenShiftAnswer(shifted.stored) == shifted)
        #expect(ScreenShiftAnswer("kept") == .kept)
        #expect(ScreenShiftAnswer("other") == nil)
    }
}
