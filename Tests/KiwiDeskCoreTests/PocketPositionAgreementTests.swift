import Testing

@testable import KiwiDeskCore

/// The Position master's agreement takes the pocket's edge, its
/// screens' included (#3401), and the Pocket position row's note
/// shows while the pocket rests on a bar's edge on some screen.
@Suite("Pocket in the Position agreement (#3401)")
struct PocketPositionAgreementTests {
    static let studio = "Studio Display:5120x2880"
    static let laptop = "Built-in Retina Display:1512x982"
    static let both = ScreenEdgeScope(screens: [studio, laptop])

    /// Both bars and the pocket on `edge` on every screen.
    private func together(_ edge: AppBarEdge) -> TilingSettings {
        var settings = TilingSettings()
        settings.spaceBarStyle.setEdge(edge)
        settings.appBarStyle.setEdge(edge)
        settings.kiwishelf.pocketEdges.setEdge(edge)
        return settings
    }

    @Test("the master selects an edge only while the pocket shares it")
    func pocketJoinsTheAgreement() {
        var settings = together(.top)
        #expect(settings.uniformBarEdge == .top)
        settings.kiwishelf.pocketEdges.setEdge(.left)
        #expect(settings.sharedBarEdge == .top)
        #expect(settings.uniformBarEdge == nil)
    }

    @Test("a screen of the pocket's own leaves the master unset")
    func pocketScreenSplits() {
        var settings = together(.top)
        settings.kiwishelf.pocketEdges.setEdge(
            .right,
            on: Self.studio,
            among: Self.both
        )
        #expect(settings.kiwishelf.pocketEdge == .top)
        #expect(settings.uniformBarEdge == nil)
    }

    @Test("the note shows while the pocket rests on a bar's edge")
    func noteFollowsTheSharedEdge() {
        var settings = together(.top)
        settings.kiwishelf.pocketVisibility = .auto
        #expect(settings.pocketSharesABarEdge)
        // Either bar's edge counts.
        settings.spaceBarStyle.setEdge(.bottom)
        #expect(settings.pocketSharesABarEdge)
        settings.appBarStyle.setEdge(.left)
        #expect(!settings.pocketSharesABarEdge)
        // A screen putting it on a bar's edge counts.
        settings.kiwishelf.pocketEdges.setEdge(
            .left,
            on: Self.studio,
            among: Self.both
        )
        #expect(settings.pocketSharesABarEdge)
        // Hidden rests nowhere.
        settings.kiwishelf.pocketVisibility = .hidden
        #expect(!settings.pocketSharesABarEdge)
    }
}
