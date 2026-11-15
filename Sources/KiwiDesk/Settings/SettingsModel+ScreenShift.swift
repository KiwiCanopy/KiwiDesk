import CoreGraphics
import Foundation
import KiwiDeskCore

/// The boxed-in offer's live state (#2756): the arrangement Core
/// read, its one offer, and the answer remembered for it.
@MainActor
struct ScreenShiftState: Equatable {
    var screens: [ArrangedScreen] = []
    var offer: ScreenOffer?
    /// The answer per arrangement key (`ScreenShiftAnswer`).
    var answers: [String: String] = [:]
    /// The offer the alert asks about; nil while it is shut.
    var asking: ScreenOffer?

    var arrangementKey: String {
        ScreenShiftPlan.arrangementKey(screens)
    }

    /// The live arrangement's answer, if one was given.
    var answer: ScreenShiftAnswer? {
        answers[arrangementKey].flatMap(ScreenShiftAnswer.init)
    }

    /// The offer the Screens row and the checklist draw a button
    /// for: a boxed-in arrangement some set of moves frees.
    var openOffer: ScreenOffer? {
        guard let offer, !offer.shifts.isEmpty else { return nil }
        return offer
    }

    /// The screen's name as copy says it, its position added where
    /// another screen shares the name.
    func name(of id: String) -> String {
        guard let screen = screens.first(where: { $0.id == id }) else {
            return id
        }
        let positions = ScreenShiftPlan.namePositions(
            screens.map { (key: $0.id, name: $0.name, frame: $0.frame) }
        )
        return ScreenShiftText.named(screen.name, at: positions[id])
    }
}

/// What the user answered the offer for one arrangement: a no,
/// or a yes, stored under the arrangement the yes produced with
/// the screens it moved.
enum ScreenShiftAnswer: Equatable {
    case kept
    case shifted([String])

    init?(_ stored: String) {
        if stored == "kept" {
            self = .kept
        } else if stored.hasPrefix("shifted:") {
            self = .shifted(
                stored.dropFirst("shifted:".count)
                    .split(separator: ",").map(String.init)
            )
        } else {
            return nil
        }
    }

    var stored: String {
        switch self {
        case .kept: return "kept"
        case .shifted(let ids):
            return "shifted:" + ids.joined(separator: ",")
        }
    }
}

extension SettingsModel {
    /// `UserDefaults.screens.shift_answers`: the answer per
    /// arrangement, so a no is not asked again until the
    /// arrangement changes.
    static let screenShiftAnswersKey = "screens.shift_answers"

    /// Reads the arrangement and its offer from Core, and the
    /// stored answers; on appear, on the app coming forward and on
    /// every screen change. A test hands `screens` in place of
    /// the live read.
    func refreshScreenOffer(_ screens: [ArrangedScreen]? = nil) {
        let screens = screens ?? core.arrangedScreens()
        var state = screenShift
        state.screens = screens
        state.offer = ScreenShiftPlan.offer(screens)
        state.answers =
            preferences.dictionary(forKey: Self.screenShiftAnswersKey)
            as? [String: String] ?? [:]
        guard state != screenShift else { return }
        screenShift = state
    }

    /// Opens the alert over `offer`.
    func askScreenShift(_ offer: ScreenOffer) {
        screenShift.asking = offer
    }

    /// The alert's Keep as Is: remembered for this arrangement.
    func keepArrangement() {
        screenShift.asking = nil
        storeScreenShiftAnswer(.kept, for: screenShift.arrangementKey)
    }

    /// The alert's Shift: the moves, then the answer filed under
    /// the arrangement they produced.
    func applyScreenShift(_ offer: ScreenOffer) {
        screenShift.asking = nil
        guard core.applyScreenShifts(offer.shifts) else {
            refreshScreenOffer()
            return
        }
        let after = core.arrangedScreens()
        storeScreenShiftAnswer(
            .shifted(offer.shifts.map(\.screen)),
            for: ScreenShiftPlan.arrangementKey(after)
        )
        refreshScreenOffer(after)
    }

    private func storeScreenShiftAnswer(
        _ answer: ScreenShiftAnswer,
        for key: String
    ) {
        var answers =
            preferences.dictionary(forKey: Self.screenShiftAnswersKey)
            as? [String: String] ?? [:]
        answers[key] = answer.stored
        preferences.set(answers, forKey: Self.screenShiftAnswersKey)
        screenShift.answers = answers
    }

    /// Whether the checklist's boxed-in row shows, and its tick:
    /// nil while no offer is open, true once kept as is.
    var screenShiftChecklistDone: Bool? {
        guard screenShift.openOffer != nil else { return nil }
        return screenShift.answer == .kept
    }
}

extension SettingsModel {
    /// A screen card's name: its position added where another
    /// connected screen shares the name, as the offer's sentences
    /// say it (#2756 ▸ the preview questions, 6).
    func screenLabel(_ display: Display) -> String {
        let positions = ScreenShiftPlan.namePositions(
            displays.map {
                // AppKit frames grow up; the positions read y-down.
                let f = $0.frame
                return (
                    key: $0.id,
                    name: $0.name,
                    frame: CGRect(
                        x: f.minX,
                        y: -f.maxY,
                        width: f.width,
                        height: f.height
                    )
                )
            }
        )
        return ScreenShiftText.named(
            display.name,
            at: positions[display.id]
        )
    }
}
