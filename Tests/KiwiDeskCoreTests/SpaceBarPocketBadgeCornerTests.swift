import AppKit
import Testing

@testable import KiwiDeskCore

/// Each state owns a corner of a Space Bar glyph (#2831 part 3):
/// a glyph grouping a pocket window and a floating one shows both
/// badges, the pocket bottom right beside floating bottom left.
@Suite("Space Bar pocket badge corner (#2831)")
@MainActor
struct SpaceBarPocketBadgeCornerTests {
    private func view(
        pocket: Bool,
        floating: Bool
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 120, height: 28)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [
                SpaceBarItemView.App(
                    name: "App",
                    icon: nil,
                    glyph: "A",
                    focused: true,
                    count: 2,
                    floating: floating,
                    pocket: pocket
                )
            ],
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "",
                floating: "",
                pocket: ""
            )
        )
        view.layout()
        return view
    }

    @Test("a group with a pocket and a float shows both badges")
    func bothBadgesShow() throws {
        let item = view(pocket: true, floating: true)
        let float = try #require(item.floatingBadgeViews.first ?? nil)
        let pocket = try #require(item.pocketBadgeViews.first ?? nil)
        #expect(pocket.symbolName == StateBadgeView.pocketName)
        #expect(float.symbolName != StateBadgeView.pocketName)
        // Same bottom edge, the pocket on the right.
        #expect(abs(pocket.frame.maxY - float.frame.maxY) < 1)
        #expect(pocket.frame.minX > float.frame.maxX)
    }

    @Test("a pocket window alone shows the pocket badge only")
    func pocketAlone() {
        let item = view(pocket: true, floating: false)
        #expect(item.floatingBadgeViews.allSatisfy { $0 == nil })
        #expect(item.pocketBadgeViews.contains { $0 != nil })
    }
}
