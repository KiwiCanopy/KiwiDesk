import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Spaces step's "Start with" model (#3294): Current leads only
/// on a changed desk, a pick writes nothing until Continue, an
/// untouched desk swaps its copy, a changed one asks once and its
/// Revert puts the Spaces back.
@Suite("Onboarding Start with (#3294)")
@MainActor
struct OnboardingStartModelTests {
    private let suggested = StarterSetup.standardLayout(
        sizes: [CGSize(width: 2560, height: 1440)]
    )

    private final class Calls {
        var started: [(String, String?)] = []
        var asked = 0
        var replaced: [String] = []
        var restored = 0
    }

    private func copy(of layout: StandardLayout) -> KiwiCore.TourCopy {
        KiwiCore.TourCopy(
            layout: layout.name,
            profile: Profile(
                name: layout.name,
                monitorSets: [],
                spaces: [],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
    }

    private func model(
        desk: KiwiCore.TourDesk,
        answer: Bool = true
    ) -> (OnboardingStartModel, Calls) {
        let start = OnboardingStartModel()
        let calls = Calls()
        let offered = [suggested, StandardProfiles.developer1]
        start.offered = { offered }
        var current = desk
        start.readDesk = { _, copy in
            // Once a copy is saved the desk is that copy, untouched.
            if let copy {
                return .untouched(
                    offered.first { $0.name == copy.layout } ?? suggested
                )
            }
            return current
        }
        start.start = { layout, from in
            calls.started.append((layout.name, from?.layout))
            current = .untouched(layout)
            return .started(
                layout.starterTitle == nil ? self.copy(of: layout) : nil
            )
        }
        start.confirmReplace = { _, reply in
            calls.asked += 1
            reply(answer)
        }
        start.replace = { layout in
            calls.replaced.append(layout.name)
            return true
        }
        start.captureBaseline = { nil }
        start.restore = { _ in
            calls.restored += 1
            return true
        }
        start.refresh()
        return (start, calls)
    }

    @Test("an untouched desk offers no Current and selects itself")
    func untouchedDesk() {
        let (start, _) = model(desk: .untouched(suggested))
        #expect(!start.deskChanged)
        #expect(start.options.map(\.id) == ["suggested", "Developer"])
        #expect(start.selected == .layout(suggested))
    }

    @Test("a changed desk leads with Current, selected")
    func changedDesk() {
        let (start, _) = model(desk: .changed)
        #expect(start.deskChanged)
        #expect(start.options.first == .current)
        #expect(start.selected == .current)
        #expect(!start.replacesCurrent)
        start.pick(.layout(StandardProfiles.developer1))
        #expect(start.replacesCurrent)
    }

    @Test("a pick writes nothing; Continue on the same choice neither")
    func pickWritesNothing() {
        let (start, calls) = model(desk: .untouched(suggested))
        start.pick(.layout(StandardProfiles.developer1))
        #expect(calls.started.isEmpty)
        start.pick(.layout(suggested))
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.started.isEmpty)
    }

    @Test("Continue on an untouched desk starts the pick from it")
    func untouchedContinue() {
        let (start, calls) = model(desk: .untouched(suggested))
        start.pick(.layout(StandardProfiles.developer1))
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.started.count == 1)
        #expect(calls.started.first?.0 == "Developer")
        // The starter is no copy, so nothing is handed in to delete.
        #expect(calls.started.first?.1 == nil)
        #expect(calls.asked == 0)
    }

    /// A second pick hands in the copy the first saved, the one
    /// profile a pick may delete.
    @Test("a second Continue hands in the copy the first saved")
    func secondContinueHandsTheCopy() {
        let (start, calls) = model(desk: .untouched(suggested))
        start.pick(.layout(StandardProfiles.developer1))
        start.commit {}
        start.pick(.layout(suggested))
        start.commit {}
        #expect(calls.started.map(\.1) == [nil, "Developer"])
    }

    /// A profile with no layout for these screens: Current leads,
    /// the pick asks once and then starts a copy, never a replace.
    @Test("a foreign desk asks, then starts a copy")
    func foreignDesk() {
        let (start, calls) = model(desk: .foreign)
        #expect(start.options.first == .current)
        start.pick(.layout(StandardProfiles.developer1))
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.asked == 1)
        #expect(calls.replaced.isEmpty)
        #expect(calls.started.count == 1)
    }

    /// A later step's write re-reads an intact copy and drops one
    /// the user changed, so that one is never deleted.
    @Test("a later write keeps an intact copy, drops a changed one")
    func laterWriteRereadsOnlyIntact() {
        let (start, calls) = model(desk: .untouched(suggested))
        start.pick(.layout(StandardProfiles.developer1))
        start.commit {}
        var reread = 0
        start.rereadCopy = { copy in
            reread += 1
            return copy
        }
        start.copyIntact = { _ in true }
        start.writingProfile {}
        #expect(start.copy != nil)
        #expect(reread == 1)
        start.copyIntact = { _ in false }
        start.writingProfile {}
        #expect(start.copy == nil)
        #expect(reread == 1)
        #expect(calls.started.count == 1)
    }

    /// No saved profile live: no Current, and a pick starts fresh.
    @Test("an unsaved desk offers no Current and replaces nothing")
    func unsavedDesk() {
        let (start, calls) = model(desk: .unsaved)
        #expect(!start.deskChanged)
        #expect(start.options.first != .current)
        start.pick(.layout(StandardProfiles.developer1))
        start.commit {}
        #expect(calls.asked == 0)
        #expect(calls.started.count == 1)
    }

    @Test("a changed desk asks once; Cancel stays with the pick")
    func changedCancel() {
        let (start, calls) = model(desk: .changed, answer: false)
        start.pick(.layout(StandardProfiles.developer1))
        var advanced = false
        start.commit { advanced = true }
        #expect(calls.asked == 1)
        #expect(!advanced)
        #expect(calls.replaced.isEmpty)
        #expect(start.selected == .layout(StandardProfiles.developer1))
    }

    @Test("a replace lands on Current, so a return asks nothing again")
    func changedReplace() {
        let (start, calls) = model(desk: .changed)
        start.pick(.layout(StandardProfiles.developer1))
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.replaced == ["Developer"])
        #expect(start.selected == .current)
        start.commit {}
        #expect(calls.asked == 1)
    }

    @Test("Continue on Current writes nothing")
    func currentWritesNothing() {
        let (start, calls) = model(desk: .changed)
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.asked == 0)
        #expect(calls.replaced.isEmpty)
    }
}
