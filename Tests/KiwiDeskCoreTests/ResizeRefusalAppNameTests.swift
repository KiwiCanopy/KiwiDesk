import Foundation
import Testing

@testable import KiwiDeskCore

/// The neighbour pill names the anchor's app: the anchor may be
/// hidden in overflow, so the trier's pill is the only place the
/// user learns which window blocked.
@Suite("Resize refusal names the neighbour's app")
@MainActor
struct ResizeRefusalAppNameTests {
    private let window = WindowID(1)
    private let other = WindowID(2)

    private func neighbor(
        appBound: Bool,
        app: String
    ) -> ResizeRefusal {
        .neighborMinimum(
            anchor: other,
            focused: window,
            axis: "x",
            appBound: appBound,
            anchorApp: app
        )
    }

    @Test("A known app is named, in both verdicts")
    func nameIsSpelled() {
        LocalizationManager.shared.select("en")
        #expect(
            neighbor(appBound: false, app: "App2").pillText
                == "Neighboring App2 window is at the minimum window size"
        )
        #expect(
            neighbor(appBound: true, app: "App2").pillText
                == "Neighboring App2 window won't go smaller"
        )
    }

    @Test("An unknown app keeps the nameless sentence")
    func emptyNameFallsBack() {
        LocalizationManager.shared.select("en")
        #expect(
            neighbor(appBound: true, app: "").pillText
                == "Neighboring app won't go smaller"
        )
        #expect(
            neighbor(appBound: false, app: "  ").pillText
                == "Neighboring window at its minimum size"
        )
    }

    @Test("Named and nameless sentences differ in every verdict")
    func fourSentencesAreDistinct() {
        let texts = [true, false].flatMap { bound in
            ["", "Safari"].map {
                neighbor(appBound: bound, app: $0).pillText
            }
        }
        #expect(Set(texts).count == 4)
    }

    @Test("A long app name is cut, and the sentence kept")
    func longNameIsCut() {
        LocalizationManager.shared.select("en")
        let long = "Microsoft Remote Desktop Beta"
        let cut = ResizeRefusal.pillAppName(long)
        #expect(cut.count == ResizeRefusal.pillAppNameLimit)
        #expect(cut.hasSuffix("…"))
        #expect(
            neighbor(appBound: true, app: long).pillText
                == "Neighboring \(cut) window won't go smaller"
        )
        // A name at the limit stays whole.
        let exact = String(
            repeating: "a",
            count: ResizeRefusal.pillAppNameLimit
        )
        #expect(ResizeRefusal.pillAppName(exact) == exact)
    }
}
