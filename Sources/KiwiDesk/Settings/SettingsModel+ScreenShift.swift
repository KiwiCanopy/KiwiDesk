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
    /// The offer the alert asks about, with the arrangement it was
    /// planned for; nil while it is shut.
    var asking: ScreenOffer?
    var askingKey: String?

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
        // Core hands over no unnamed screen (`arrangedScreens`).
        guard let screen = screens.first(where: { $0.id == id }) else {
            return ""
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
        // An open alert asks about the arrangement it was planned
        // for; a screen change under it closes it unanswered.
        if state.askingKey != state.arrangementKey {
            state.asking = nil
            state.askingKey = nil
        }
        guard state != screenShift else { return }
        screenShift = state
    }

    /// Opens the alert over `offer`.
    func askScreenShift(_ offer: ScreenOffer) {
        screenShift.askingKey = screenShift.arrangementKey
        screenShift.asking = offer
    }

    /// The alert's Keep as Is: remembered for the arrangement it
    /// asked about.
    func keepArrangement() {
        let key = screenShift.askingKey ?? screenShift.arrangementKey
        screenShift.asking = nil
        screenShift.askingKey = nil
        storeScreenShiftAnswer(.kept, for: key)
    }

    /// The alert's Shift: the moves, then the answer filed under
    /// the arrangement they produced.
    /// The plan itself waits for macOS's screen-change notice,
    /// since the usable areas it scores are AppKit's and change
    /// only then.
    func applyScreenShift(_ offer: ScreenOffer) {
        screenShift.asking = nil
        screenShift.askingKey = nil
        guard core.applyScreenShifts(offer.shifts) else {
            refreshScreenOffer()
            return
        }
        storeScreenShiftAnswer(
            .shifted(offer.shifts.map(\.screen)),
            for: ScreenShiftPlan.arrangementKey(core.arrangedScreens())
        )
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
    /// A screen card's name, from the same screens the offer's
    /// sentences name, so the two say one name (#2756 ▸ the
    /// preview questions, 6).
    func screenLabel(_ display: Display) -> String {
        let state = screenShift
        guard
            let screen = state.screens.first(where: {
                $0.display == display.id
            })
        else { return display.name }
        return state.name(of: screen.id)
    }
}
