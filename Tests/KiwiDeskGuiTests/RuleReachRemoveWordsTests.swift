import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The trash's second choice names who it removes from (#1393):
/// every profile only when that is all of them, two by name, more
/// by count — never "every profile" while one keeps its own value.
@Suite("Rule trash words (#1393)", .serialized)
@MainActor
struct RuleReachRemoveWordsTests {
    private let names = ["Work", "Home", "Travel", "Lab"]

    private func reading(_ users: Set<String>) -> RuleReachReading {
        RuleReachReading(
            editing: "Work",
            loaded: "Work",
            profiles: names,
            unreadable: [],
            shared: true,
            hasShared: true,
            users: users,
            own: [:],
            ownIsShared: [],
            leftOut: []
        )
    }

    @Test("every profile only when all of them hold the value")
    func everyProfile() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RuleReachWords.removeEverywhere(reading(Set(names)))
                == "Remove from every profile"
        )
    }

    @Test("two holders by name, in menu order")
    func twoByName() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RuleReachWords.removeEverywhere(reading(["Home", "Work"]))
                == "Remove from Work and Home"
        )
    }

    @Test("three or more holders, short of all, by count")
    func moreByCount() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RuleReachWords.removeEverywhere(reading(["Work", "Home", "Lab"]))
                == "Remove from every profile using it (3)"
        )
    }
}
