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
        #expect(settings.uniformShelfEdge == .top)
        settings.kiwishelf.pocketEdges.setEdge(.left)
        #expect(settings.sharedBarEdge == .top)
        #expect(settings.uniformShelfEdge == nil)
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
        #expect(settings.uniformShelfEdge == nil)
    }

    /// Shown bars on `edge`, the pocket there under Auto, and no
    /// App Bar drawn in any layout, so the Space Bar alone decides.
    private func spaceBarOnly(_ edge: AppBarEdge) -> TilingSettings {
        var settings = together(edge)
        settings.spaceBarStyle.visibility = .always
        settings.kiwishelf.pocketVisibility = .auto
        for mode in LayoutMode.allCases {
            settings.setAppBarVisibility(.hidden, in: mode)
        }
        return settings
    }

    @Test("the note shows while the pocket rests as a bar's section")
    func noteFollowsTheSection() {
        var settings = spaceBarOnly(.top)
        #expect(settings.pocketSharesABarEdge)
        // A bar on the edge that draws nothing at rest leaves the
        // pocket a handle, so it takes its own position.
        settings.spaceBarStyle.visibility = .auto
        #expect(!settings.pocketSharesABarEdge)
        settings.spaceBarStyle.visibility = .hidden
        #expect(!settings.pocketSharesABarEdge)
        // A hidden App Bar on that edge does not make it a section.
        settings.appBarStyle.setEdge(.top)
        #expect(!settings.pocketSharesABarEdge)
        // A screen that puts the pocket on the shown bar's edge.
        settings = spaceBarOnly(.top)
        settings.kiwishelf.pocketEdges.setEdge(.left)
        #expect(!settings.pocketSharesABarEdge)
        settings.kiwishelf.pocketEdges.setEdge(
            .top,
            on: Self.studio,
            among: Self.both
        )
        #expect(settings.pocketSharesABarEdge)
        // Hidden rests nowhere.
        settings.kiwishelf.pocketVisibility = .hidden
        #expect(!settings.pocketSharesABarEdge)
    }
}
