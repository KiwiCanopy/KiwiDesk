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

    private func model(
        untouched: StandardLayout?,
        answer: Bool = true
    ) -> (OnboardingStartModel, Calls) {
        let start = OnboardingStartModel()
        let calls = Calls()
        let offered = [suggested, StandardProfiles.developer1]
        start.offered = { offered }
        start.untouchedChoice = { _ in untouched }
        start.start = { layout, from in
            calls.started.append((layout.name, from?.name))
            return true
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
        let (start, _) = model(untouched: suggested)
        #expect(!start.deskChanged)
        #expect(start.options.map(\.id) == ["suggested", "Developer"])
        #expect(start.selected == .layout(suggested))
    }

    @Test("a changed desk leads with Current, selected")
    func changedDesk() {
        let (start, _) = model(untouched: nil)
        #expect(start.deskChanged)
        #expect(start.options.first == .current)
        #expect(start.selected == .current)
        #expect(!start.replacesCurrent)
        start.pick(.layout(StandardProfiles.developer1))
        #expect(start.replacesCurrent)
    }

    @Test("a pick writes nothing; Continue on the same choice neither")
    func pickWritesNothing() {
        let (start, calls) = model(untouched: suggested)
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
        let (start, calls) = model(untouched: suggested)
        start.pick(.layout(StandardProfiles.developer1))
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.started.count == 1)
        #expect(calls.started.first?.0 == "Developer")
        #expect(calls.started.first?.1 == StarterSetup.name)
        #expect(calls.asked == 0)
    }

    @Test("a changed desk asks once; Cancel stays with the pick")
    func changedCancel() {
        let (start, calls) = model(untouched: nil, answer: false)
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
        let (start, calls) = model(untouched: nil)
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
        let (start, calls) = model(untouched: nil)
        var advanced = false
        start.commit { advanced = true }
        #expect(advanced)
        #expect(calls.asked == 0)
        #expect(calls.replaced.isEmpty)
    }
}
