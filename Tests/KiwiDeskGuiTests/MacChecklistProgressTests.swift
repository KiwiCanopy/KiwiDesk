import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The one count (#1365): essentials only, a row done when macOS
/// says so or — only where macOS would not answer — when the
/// user ticked it, read by the Home card and the section header
/// from the model's one snapshot.
@MainActor
@Suite("Mac Checklist progress", .serialized)
struct MacChecklistProgressTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    /// The essentials are the census's essential container, in
    /// its order, and nothing else counts: an optional row set
    /// moves no number.
    @Test("the count is the essentials, from the census")
    func essentialsComeFromTheCensus() {
        let fromCensus = MacChecklistRowOrder.essentialSettings
            .compactMap { key -> MacSetting? in
                guard case .macChecklist(let k) = key else {
                    return nil
                }
                return k.setting
            }
        #expect(MacChecklistProgress.essentials == fromCensus)
        #expect(MacChecklistProgress.total == fromCensus.count)
        let optionals = Set(
            MacChecklistRowOrder.optionalSettings.compactMap {
                key -> MacSetting? in
                guard case .macChecklist(let k) = key else {
                    return nil
                }
                return k.setting
            }
        )
        #expect(!optionals.isEmpty)
        var states: [MacSetting: MacSettingState] = [:]
        for setting in optionals { states[setting] = .set }
        #expect(
            MacChecklistProgress.done(states: states, ticks: [])
                == 0
        )
    }

    /// A read of `.set` counts; `.notSet` never does, ticked or
    /// not — a tick cannot override what macOS actually says;
    /// `.unreadable` counts only with the tick.
    @Test("a tick counts only where macOS would not answer")
    func tickCountsOnlyWhenUnreadable() {
        let first = MacChecklistProgress.essentials[0]
        for (state, ticked, done) in [
            (MacSettingState.set, false, true),
            (.set, true, true),
            (.notSet, false, false),
            (.notSet, true, false),
            (.unreadable, false, false),
            (.unreadable, true, true),
        ] {
            #expect(
                MacChecklistProgress.isDone(
                    first,
                    states: [first: state],
                    ticks: ticked ? [first] : []
                ) == done,
                "\(state) ticked=\(ticked)"
            )
        }
        // A row the snapshot never read is not done either.
        #expect(
            !MacChecklistProgress.isDone(
                first,
                states: [:],
                ticks: [first]
            )
        )
    }

    /// The model refreshes through the injected seam into one
    /// snapshot, and the count and the card subtitle read it.
    @Test("the model's refresh feeds the count")
    func refreshFeedsTheCount() {
        pinEnglish()
        defer { reset() }
        let model = makeTestModel()
        model.refreshMacChecklist()
        // Everything absent: only Stage Manager ships off.
        #expect(model.macChecklistDone == 1)
        #expect(
            HomeCardContent.subtitle(
                for: .macChecklist,
                model: model
            ) == "Essentials done: 1 of 4"
        )
        model.readMacSetting = { setting in
            .value(setting.target)
        }
        model.refreshMacChecklist()
        #expect(model.macChecklistDone == 4)
        #expect(
            HomeCardContent.subtitle(
                for: .macChecklist,
                model: model
            ) == "All essentials done"
        )
        #expect(
            MacChecklistText.progress(done: 4, total: 4)
                == "All done"
        )
        #expect(
            MacChecklistText.progress(done: 2, total: 4)
                == "Done: 2 of 4"
        )
    }

    /// The card face draws `verdicts` and `done` counts the same
    /// value, so the face cannot show a row the count does not
    /// — a face iterating `MacSetting.allCases` drew six ticks
    /// under "of 4" with every suite green (architect-reviewer,
    /// 2026-09-14).
    @Test("the face's verdicts are what the count counts")
    func verdictsAreTheCount() {
        let first = MacChecklistProgress.essentials[0]
        let states: [MacSetting: MacSettingState] = [
            first: .set, MacChecklistProgress.essentials[1]: .unreadable,
        ]
        let ticks: Set<MacSetting> = [
            MacChecklistProgress.essentials[1]
        ]
        let verdicts = MacChecklistProgress.verdicts(
            states: states,
            ticks: ticks
        )
        #expect(verdicts.map(\.setting) == MacChecklistProgress.essentials)
        #expect(
            verdicts.filter(\.done).count
                == MacChecklistProgress.done(states: states, ticks: ticks)
        )
        #expect(verdicts.filter(\.done).count == 2)
        // A wrong-kind read is unreadable, and the one reading of
        // an unread row is "not set".
        #expect(
            MacChecklistProgress.state(of: first, in: [:]) == .notSet
        )
    }

    /// The fallback tick lives in the model's preferences store
    /// under the census key, per machine, and reaches the count
    /// only for an unreadable row.
    @Test("a self-tick is stored per machine and counted")
    func selfTickIsStoredAndCounted() {
        let model = makeTestModel()
        let first = MacChecklistProgress.essentials[0]
        model.readMacSetting = { setting in
            setting == first ? .other : .absent
        }
        model.refreshMacChecklist()
        #expect(model.macChecklistStates[first] == .unreadable)
        let before = model.macChecklistDone
        model.setMacChecklistTick(first, true)
        #expect(model.macChecklistTicks == [first])
        #expect(
            model.preferences.stringArray(
                forKey: SettingsModel.macChecklistTicksKey
            ) == [first.rawValue]
        )
        #expect(model.macChecklistDone == before + 1)
        model.setMacChecklistTick(first, false)
        #expect(model.macChecklistTicks.isEmpty)
        #expect(model.macChecklistDone == before)
        // The published mirror is seeded from the store, so a
        // tick survives the model that wrote it.
        model.setMacChecklistTick(first, true)
        let again = makeTestModel(defaults: model.preferences)
        #expect(again.macChecklistTicks == [first])
    }

    /// The census key names the store the model writes.
    @Test("the tick store is the census's internal key")
    func tickStoreIsTheCensusKey() {
        #expect(
            MacChecklistKey.selfTicks.rawValue
                == "UserDefaults." + SettingsModel.macChecklistTicksKey
        )
        #expect(
            MacChecklistKey.selfTicks.placement.tier == .internalOnly
        )
    }
}
