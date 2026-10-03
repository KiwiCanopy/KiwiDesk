import AppKit
import Testing

@testable import KiwiDeskCore

@Suite("Space Bar inline title motion")
@MainActor
struct SpaceBarInlineTitleMotionTests {
    private func configure(
        _ view: SpaceBarItemView,
        drawn: ClosedRange<UInt32>,
        space: SpaceID = SpaceID("1"),
        title: String? = "A long window title",
        layout: Bool = true
    ) {
        let apps = drawn.map { id in
            SpaceBarItemView.App(
                name: "App",
                inlineTitle: title,
                icon: NSImage(size: NSSize(width: 16, height: 16)),
                glyph: nil,
                focused: false,
                count: 1,
                windows: [WindowID(id)]
            )
        }
        view.configure(
            identity: .space(space),
            spaceGlyph: .text("1", tinted: true),
            apps: apps,
            active: true,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(sticky: "", floating: ""),
            before: .init(windows: (1..<drawn.lowerBound).map(WindowID.init)),
            after: .init(
                windows: ((drawn.upperBound + 1)..<10).map(WindowID.init)
            ),
            drawn: .init(
                window: Int(drawn.lowerBound - 1)..<Int(drawn.upperBound),
                count: 9
            )
        )
        if layout { view.layout() }
    }

    @Test("an inline strip walks glyphs and titles by measured widths")
    func measuredWalk() throws {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 1400, height: 32)
        )
        configure(view, drawn: 3...7)
        let old = view.appViews[1].frame.minX
        let oldTitle = view.titleViews[0]
        configure(view, drawn: 4...8)
        let shift = old - view.appViews[0].frame.minX
        #expect(shift > view.appViews[0].frame.width * 2)
        let plays = !BarMotion.isReduced
        for part in [view.appViews[0], view.titleViews[0]] {
            let animation =
                part.layer?.animation(forKey: "kiwi.walk.slide")
                as? CABasicAnimation
            #expect((animation != nil) == plays)
            if plays {
                let value = try #require(animation?.fromValue as? NSValue)
                #expect(abs(value.pointValue.x - shift) < 0.01)
            }
        }
        #expect(
            (oldTitle.layer?.animation(forKey: "kiwi.walk.fade") != nil)
                == plays
        )
        #expect(
            (view.titleViews.last?.layer?.animation(
                forKey: "kiwi.walk.fade"
            ) != nil) == plays
        )
        #expect(view.pendingWalk == nil)
    }

    @Test("a repeated render preserves an inline transition before layout")
    func repeatedRender() throws {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 1400, height: 32)
        )
        configure(view, drawn: 3...7)
        let old = view.appViews[1].frame
        configure(view, drawn: 4...8, layout: false)
        configure(view, drawn: 4...8, layout: false)
        #expect(view.pendingTitleReveal)
        #expect(view.pendingInlineWalk)
        #expect(view.titleTransitionFrames[WindowID(4)] == old)
        view.layout()
        #expect(!view.pendingTitleReveal)
        #expect(!view.pendingInlineWalk)
        #expect(view.pendingWalk == nil)
        #expect(
            (view.titleViews[0].layer?.animation(
                forKey: "kiwi.walk.slide"
            ) != nil) == !BarMotion.isReduced
        )
    }

    @Test("a pooled chip starts without another Space's title positions")
    func newIdentity() {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 1400, height: 32)
        )
        configure(view, drawn: 3...7)
        let oldTitle = view.titleViews[1]
        configure(view, drawn: 4...6, space: SpaceID("2"), layout: false)
        #expect(view.pendingTitleReveal)
        #expect(view.titleTransitionFrames.isEmpty)
        #expect(view.drawnTitleWindows.isEmpty)
        #expect(oldTitle.superview == nil)
        view.layout()
        #expect(
            view.titleViews[0].layer?.animation(
                forKey: "kiwi.walk.slide"
            ) == nil
        )
    }

    @Test("a repeated render settles glyphs and titles together mid-walk")
    func repeatedRenderAfterLayout() {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 1400, height: 32)
        )
        configure(view, drawn: 3...7)
        configure(view, drawn: 4...8)
        let oldTitle = view.titleViews[0]
        configure(view, drawn: 4...8)
        #expect(oldTitle.superview == nil)
        for part in [view.appViews[0], view.titleViews[0]] {
            #expect(part.layer?.animation(forKey: "kiwi.walk.slide") == nil)
        }
        #expect(!view.pendingTitleReveal)
    }

    @Test("icon-only renders do not start inline title motion")
    func iconOnlyRender() {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 1400, height: 32)
        )
        configure(view, drawn: 3...7, title: nil, layout: false)
        #expect(!view.pendingTitleReveal)
        view.layout()
        configure(view, drawn: 3...6, title: nil, layout: false)
        #expect(!view.pendingTitleReveal)
        #expect(!view.pendingInlineWalk)
    }

}
