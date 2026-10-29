import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What a Simple Space card and app row draw from shared parts
/// (#2777): the bar picture lights the card's own Space past the
/// eighth, and an app row names its reach only when narrower than
/// every profile. Main-actor spend: building one bars tile.
@Suite("Simple Space card and reach")
@MainActor
struct SimpleSpaceCardReachTests {
    @Test("a card past the eighth Space lights itself")
    func ninthSpaceIsLit() {
        let tile = HomeCardBarsTile(
            settings: TilingSettings(),
            pocketStands: false,
            spaceCount: 9,
            scale: 1,
            activeSpace: 8
        )
        let items = tile.spaceItems(KiwiShelf())
        #expect(items.count == 8)
        #expect(items.last?.active == true)
        #expect(items.filter(\.active).count == 1)
    }

    private func reading(
        shared: Bool = true,
        own: [String: String] = [:],
        leftOut: Set<String> = [],
        unreadable: [String] = []
    ) -> RuleReachReading {
        RuleReachReading(
            editing: "Work",
            loaded: "Work",
            profiles: ["Home", "Work"],
            unreadable: unreadable,
            shared: shared,
            hasShared: shared,
            users: ["Home", "Work"],
            own: own,
            ownIsShared: [],
            leftOut: leftOut
        )
    }

    @Test("only a key every profile resolves goes unnamed")
    func everyProfile() {
        #expect(reading().reachesEveryProfile)
        #expect(!reading(shared: false).reachesEveryProfile)
        #expect(!reading(leftOut: ["Home"]).reachesEveryProfile)
        #expect(!reading(own: ["Home": "⌃⌥X"]).reachesEveryProfile)
        #expect(!reading(unreadable: ["Old"]).reachesEveryProfile)
    }
}
