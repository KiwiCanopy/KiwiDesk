import KiwiDeskCore
import SwiftUI

/// One "Start with" segment on the tour's Spaces step (#3294).
enum OnboardingStartOption: Equatable, Identifiable {
    /// The Spaces the desk has now, on a replay over a changed desk.
    case current
    /// The starter ("Suggested") or a preset.
    case layout(StandardLayout)

    var id: String {
        switch self {
        case .current: return "current"
        case .layout(let layout):
            return layout.starterTitle == nil ? layout.name : "suggested"
        }
    }

    var layout: StandardLayout? {
        if case .layout(let layout) = self { return layout }
        return nil
    }
}

/// The Spaces step's "Start with" choice (#3294, owner rulings
/// 2026-11-13). A pick redraws the cards and writes nothing; the
/// step's Continue makes it live. On an untouched desk that is a
/// fresh preset copy, the one it replaces deleted; on a changed
/// desk it is the live profile's Spaces replaced in place, asked
/// once, with the step's Revert as its undo while the tour is open.
@MainActor
@Observable
final class OnboardingStartModel {
    private(set) var options: [OnboardingStartOption] = []
    var selected: OnboardingStartOption?
    /// What the desk is to the step: the offered layout it still
    /// is, the user's own Spaces, or no saved profile at all.
    private(set) var desk: KiwiCore.TourDesk = .unsaved
    /// The preset copy this presentation saved: the one profile a
    /// later pick may delete, and only while it is untouched.
    private(set) var copy: KiwiCore.TourCopy?
    /// The Spaces before this presentation's first replace.
    private(set) var baseline: KiwiCore.TourSpacesBaseline?
    private(set) var revision = 0

    /// The layouts the connected screens are offered, starter first.
    var offered: () -> [StandardLayout] = { [] }
    var readDesk: ([StandardLayout], KiwiCore.TourCopy?) -> KiwiCore.TourDesk =
        { _, _ in .unsaved }
    /// The cards an option draws, one column per screen.
    var columns: (OnboardingStartOption) -> [OnboardingScreenColumn] = {
        _ in []
    }
    /// Makes a pick live where nothing of the user's is replaced,
    /// deleting the copy handed in; nil where it failed, else the
    /// new preset copy it saved, if any.
    var start: (StandardLayout, KiwiCore.TourCopy?) -> StartOutcome = {
        _,
        _ in .failed
    }
    /// Asks once before a changed desk's Spaces are replaced; the
    /// answer comes back through the closure, true for Replace.
    var confirmReplace: (StandardLayout, @escaping (Bool) -> Void) -> Void =
        { _, answer in answer(false) }
    var replace: (StandardLayout) -> Bool = { _ in false }
    var captureBaseline: () -> KiwiCore.TourSpacesBaseline? = { nil }
    var restore: (KiwiCore.TourSpacesBaseline) -> Bool = { _ in false }
    /// The copy re-read after a later step of the tour wrote it.
    var rereadCopy: (KiwiCore.TourCopy) -> KiwiCore.TourCopy? = { $0 }
    /// Whether the copy's file still reads as saved.
    var copyIntact: (KiwiCore.TourCopy) -> Bool = { _ in true }

    /// What a start came to.
    enum StartOutcome {
        case failed
        case started(KiwiCore.TourCopy?)
    }

    /// The offered layout the desk still is; nil otherwise.
    var untouched: StandardLayout? {
        if case .untouched(let layout) = desk { return layout }
        return nil
    }

    /// Whether the desk changed, so a pick replaces its Spaces.
    var deskChanged: Bool { desk == .changed || desk == .foreign }

    /// Whether Continue now replaces the current Spaces.
    var replacesCurrent: Bool {
        deskChanged && selected?.layout != nil
    }

    var hasReplaced: Bool { baseline != nil }

    /// Reads the desk again: which options it is offered, and which
    /// one it still is. A pick already made stays while offered.
    func refresh() {
        let layouts = offered()
        desk = readDesk(layouts, copy)
        let picks = layouts.map(OnboardingStartOption.layout)
        options = deskChanged ? [.current] + picks : picks
        if let selected, options.contains(selected) { return }
        selected = untouched.map(OnboardingStartOption.layout) ?? options.first
        revision += 1
    }

    func pick(_ option: OnboardingStartOption) {
        guard options.contains(option) else { return }
        selected = option
        revision += 1
    }

    /// The step's Continue: `advance` runs once the pick is live,
    /// or at once where nothing is to write. A Cancel stays on the
    /// step with the pick kept.
    func commit(then advance: @escaping () -> Void) {
        guard let layout = selected?.layout else { return advance() }
        guard deskChanged else {
            guard layout != untouched else { return advance() }
            // Only a copy this presentation saved, still untouched,
            // is deleted.
            let outcome = start(layout, untouched == nil ? nil : copy)
            if case .started(let made) = outcome { copy = made }
            refresh()
            if case .started = outcome { advance() }
            return
        }
        confirmReplace(layout) { [weak self] replace in
            guard replace, let self else { return }
            // A profile with no layout for these screens is left as
            // saved: the confirmed pick starts a copy instead.
            if self.desk == .foreign {
                let outcome = self.start(layout, nil)
                if case .started(let made) = outcome { self.copy = made }
                self.refresh()
                if case .started = outcome { advance() }
                return
            }
            if self.baseline == nil { self.baseline = self.captureBaseline() }
            let done = self.replace(layout)
            // What was picked is the desk now: Continue again writes
            // nothing, and a Back return asks nothing again.
            if done { self.selected = .current }
            self.refresh()
            if done { advance() }
        }
    }

    /// Puts back the Spaces the first replace changed.
    func revert() {
        guard let baseline, restore(baseline) else { return }
        self.baseline = nil
        selected = nil
        refresh()
    }

    /// Runs a later step's write of the live profile (the look,
    /// the bars): an intact copy stays this tour's, re-read after
    /// it; one the user changed before it is theirs, never deleted.
    func writingProfile<T>(_ write: () -> T) -> T {
        let intact = copy.map(copyIntact) ?? false
        let result = write()
        copy = intact ? copy.flatMap(rereadCopy) : nil
        return result
    }

    /// A new presentation starts with no baseline and no pick.
    func reset() {
        baseline = nil
        copy = nil
        desk = .unsaved
        selected = nil
        options = []
    }
}
