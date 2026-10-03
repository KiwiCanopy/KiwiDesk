import AppKit
import Testing

@testable import KiwiDeskCore

@Suite("Space Bar inline hover hold", .serialized)
@MainActor
struct SpaceBarInlineHoverHoldTests {
    private func configure(
        _ view: SpaceBarItemView,
        active: Bool = false,
        space: SpaceID = "2"
    ) {
        var look = SpaceBarLook()
        look.showHoverTitles = true
        view.configure(
            identity: .space(space),
            spaceGlyph: .text("2", tinted: true),
            apps: (4...5).map {
                .init(
                    name: "App",
                    icon: nil,
                    glyph: "A",
                    focused: false,
                    count: 1,
                    windows: [WindowID(UInt32($0))]
                )
            },
            active: active,
            horizontal: true,
            style: look,
            stateMarkColors: .init(sticky: "", floating: "")
        )
        view.layout()
    }

    private func fixture() -> (NSWindow, SpaceBarItemView) {
        let window = NSWindow(
            contentRect: CGRect(x: 200, y: 200, width: 800, height: 80),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let view = SpaceBarItemView(
            frame: CGRect(x: 100, y: 0, width: 180, height: 32)
        )
        window.isReleasedWhenClosed = false
        window.contentView?.addSubview(view)
        configure(view)
        return (window, view)
    }

    @Test("a stationary pointer retains its title through relayout")
    func geometryCannotCloseOrSwitch() throws {
        let prior = BarHoverHit.pointerOverride
        let (window, view) = fixture()
        defer {
            view.clearTitleHover()
            window.close()
            BarHoverHit.pointerOverride = prior
        }
        let actions = SpaceBarGlyphActions()
        var requests: [WindowID?] = []
        actions.hover = { _, id in requests.append(id) }
        view.glyphActions = actions
        let point = view.convert(
            CGPoint(x: 150, y: 16),
            to: nil
        )
        BarHoverHit.pointerOverride = { _ in point }
        view.reportTitleHover(view.glyphTargets[0], pointerMoved: true)
        try #require(view.titleHoverAnchor?.window == WindowID(4))
        view.frame = CGRect(x: 20, y: 0, width: 160, height: 32)
        configure(view)
        view.reportTitleHover(nil)
        view.reportTitleHover(view.glyphTargets[1])
        #expect(view.pollTitleHover())
        #expect(requests == [WindowID(4)])
        #expect(view.titleHoverAnchor?.window == WindowID(4))
        let nextPoint = view.convert(
            CGPoint(x: view.glyphTargets[1].frame.midX, y: 16),
            to: nil
        )
        BarHoverHit.pointerOverride = { _ in nextPoint }
        view.reportTitleHover(view.glyphTargets[1], pointerMoved: true)
        #expect(requests == [WindowID(4), WindowID(5)])
        BarHoverHit.pointerOverride = { _ in BarHoverHit.offWindow }
        #expect(!view.pollTitleHover())
        #expect(requests == [WindowID(4), WindowID(5), nil])
        #expect(view.titleHoverWatch == nil)
        #expect(!view.pollTitleHover())
        #expect(requests.count == 3)
    }

    @Test("activation and reuse retire the held title")
    func identityAndActivationClear() {
        let prior = BarHoverHit.pointerOverride
        let (window, view) = fixture()
        defer {
            view.clearTitleHover()
            window.close()
            BarHoverHit.pointerOverride = prior
        }
        let point = view.convert(CGPoint(x: 120, y: 16), to: nil)
        BarHoverHit.pointerOverride = { _ in point }
        view.reportTitleHover(view.glyphTargets[0], pointerMoved: true)
        #expect(view.titleHoverAnchor != nil)
        configure(view, active: true)
        #expect(view.titleHoverAnchor == nil)
        #expect(view.titleHoverWatch == nil)
        configure(view)
        view.reportTitleHover(view.glyphTargets[0], pointerMoved: true)
        #expect(view.titleHoverAnchor != nil)
        configure(view, space: "3")
        #expect(view.titleHoverAnchor == nil)
        #expect(view.titleHoverWatch == nil)
    }

    @Test("a relayout cannot open another chip under a resting pointer")
    func restingPointerCannotOpenAnotherTitle() throws {
        let prior = BarHoverHit.pointerOverride
        let (window, held) = fixture()
        let moved = SpaceBarItemView(frame: held.frame)
        window.contentView?.addSubview(moved)
        configure(moved, space: "3")
        defer {
            held.clearTitleHover()
            moved.clearTitleHover()
            window.close()
            BarHoverHit.pointerOverride = prior
        }
        let point = held.convert(CGPoint(x: 120, y: 16), to: nil)
        BarHoverHit.pointerOverride = { _ in point }
        let manager = SpaceBarManager()
        let actions = SpaceBarGlyphActions()
        actions.hover = { space, id in
            _ = manager.setTitleHover(space, window: id)
        }
        held.glyphActions = actions
        moved.glyphActions = actions
        held.reportTitleHover(held.glyphTargets[0], pointerMoved: true)
        try #require(manager.titleHoveredWindow(in: "2") == WindowID(4))
        moved.reportTitleHover(moved.glyphTargets[0])
        #expect(moved.titleHoverAnchor == nil)
        #expect(manager.titleHoveredWindow(in: "3") == nil)
        #expect(manager.titleHoveredWindow(in: "2") == WindowID(4))
        moved.reportTitleHover(moved.glyphTargets[0], pointerMoved: true)
        #expect(manager.titleHoveredWindow(in: "3") == WindowID(4))
        #expect(held.titleHoverAnchor == nil)
        #expect(held.titleHoverWatch == nil)
        #expect(actions.titleHoverOwner === moved)
        held.reportTitleHover(held.glyphTargets[0], pointerMoved: true)
        #expect(manager.titleHoveredWindow(in: "2") == WindowID(4))
        #expect(moved.titleHoverAnchor == nil)
        #expect(actions.titleHoverOwner === held)
    }

    @Test("inline growth resizes the box in the shelf animation group")
    func widthTravelsWithoutTranslation() {
        let overlay = SpaceBarOverlay()
        let view = SpaceBarItemView(
            frame: CGRect(x: 10, y: 0, width: 80, height: 32)
        )
        overlay.itemViews = [view]
        overlay.itemRun.addSubview(view)
        overlay.resizesInlineTitles = true
        overlay.inlineResizeShift = 30
        let end = CGRect(x: 40, y: 0, width: 240, height: 32)
        var writes = 0
        overlay.moveFrame = { item, frame, animated in
            writes += 1
            #expect(item.frame.origin == end.origin)
            #expect(item.frame.width == 80)
            #expect(frame == end)
            #expect(animated)
            #expect(
                NSAnimationContext.current.duration
                    == BarMotion.shelfGlideLength
            )
        }
        overlay.placeItems([end], glides: false)
        #expect(writes == 1)
    }

    @Test("neighboring boxes travel from their previous spacing")
    func neighborsTravelWithGrowth() {
        let overlay = SpaceBarOverlay()
        let frames = [
            CGRect(x: 10, y: 0, width: 80, height: 32),
            CGRect(x: 100, y: 0, width: 80, height: 32),
        ]
        overlay.itemViews = frames.map { SpaceBarItemView(frame: $0) }
        overlay.itemViews.forEach { overlay.itemRun.addSubview($0) }
        overlay.resizesInlineTitles = true
        overlay.inlineResizeShift = 30
        let ends = [
            CGRect(x: 40, y: 0, width: 240, height: 32),
            CGRect(x: 290, y: 0, width: 80, height: 32),
        ]
        var starts: [CGRect] = []
        overlay.moveFrame = { item, _, animated in
            starts.append(item.frame)
            #expect(animated)
        }
        overlay.placeItems(ends, glides: false)
        #expect(starts == frames.map { $0.offsetBy(dx: 30, dy: 0) })
        #expect(starts[1].minX != ends[1].minX)
    }
}
