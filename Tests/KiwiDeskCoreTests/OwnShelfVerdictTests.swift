import Testing

@testable import KiwiDeskCore

/// The bars' own Show and edge verdicts (#3612): what Settings' Each
/// bar and Pocket holds open on. A screen's or area's own value sets
/// the uniform verdicts aside but never the own ones; the bars'
/// own values differing sets both aside.
@Suite("Own shelf verdicts (#3612)")
struct OwnShelfVerdictTests {
    private let area = "Wide:3440x1440#1"

    @Test("an area's own Show leaves the own verdict standing")
    func areaShowIsNotOwn() {
        var settings = TilingSettings()
        settings.setEveryBarVisibility(.auto)
        settings.spaceBarStyle.setVisibility(.hidden, on: area)
        #expect(settings.uniformBarVisibility == nil)
        #expect(settings.ownBarVisibility == .auto)
        settings.kiwishelf.pocketVisibility = .always
        #expect(settings.ownBarVisibility == nil)
    }

    @Test("an area's own edge leaves the own verdict standing")
    func areaEdgeIsNotOwn() {
        var settings = TilingSettings()
        settings.spaceBarStyle.edge = .top
        settings.appBarStyle.edge = .top
        settings.kiwishelf.pocketEdge = .top
        settings.spaceBarStyle.edgeOverride = [area: .left]
        #expect(settings.uniformShelfEdge == nil)
        #expect(settings.ownShelfEdge == .top)
        settings.kiwishelf.pocketEdge = .bottom
        #expect(settings.ownShelfEdge == nil)
        settings.kiwishelf.pocketEdge = .top
        settings.appBarStyle.edge = .bottom
        #expect(settings.ownShelfEdge == nil)
    }

    @Test("an area pinned to its bar's own edge differs in nothing")
    func equalPinIsNoDifference() {
        var settings = TilingSettings()
        settings.spaceBarStyle.edge = .top
        settings.appBarStyle.edge = .top
        settings.kiwishelf.pocketEdge = .top
        settings.spaceBarStyle.edgeOverride = [area: .top]
        #expect(settings.hasScreenEdges)
        #expect(!settings.screenEdgesDiffer)
        #expect(settings.uniformShelfEdge == .top)
        settings.spaceBarStyle.edgeOverride = [area: .left]
        #expect(settings.screenEdgesDiffer)
    }
}
