import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A revealed bar lands under its handle (#3359): the live plan
/// places the drawn bars in their slots of the arrangement of every
/// bar resting on the edge, the one arrangement the handle and the
/// hold read, so a reveal moves no sibling.
@MainActor
@Suite("A revealed bar lands under its handle (#3359)")
struct ShelfLandingTests {
    private func items() -> [SpaceBarOverlay.Item] {
        (1...3).map {
            SpaceBarOverlay.Item(
                space: SpaceID("\($0)"),
                spaceGlyph: .text("\($0)", tinted: false),
                apps: [],
                active: $0 == 1,
                after: .none
            )
        }
    }

    private func app(
        _ settings: TilingSettings,
        windows count: Int = 3
    ) -> KiwiCore.AppBarContent {
        let windows = (1...count).map {
            AppBarOverlay.Item(
                id: WindowID(UInt32($0)),
                text: "Window \($0)",
                icon: nil
            )
        }
        return KiwiCore.AppBarContent(
            space: Space(id: "s", mode: .monocle),
            style: settings.appBarLook(for: settings.monocle.appBar),
            groups: windows.map { [$0.id] },
            items: windows
        )
    }

    /// Both bars on the top edge of a `width` wide screen, the
    /// pass drawing `drawn`.
    private func plan(
        _ drawn: Set<ShelfBar>,
        space: ShelfVisibility = .auto,
        app appVisibility: ShelfVisibility = .auto,
        alignment: KiwiShelf.Alignment = .center,
        width: CGFloat = 1600,
        windows: Int = 3
    ) throws -> KiwiCore.ShelfPlan {
        let core = makeTestCore()
        var settings = core.tiler.settings
        settings.spaceBarStyle.edge = .top
        settings.appBarStyle.edge = .top
        settings.spaceBarStyle.visibility = space
        settings.monocle.appBar.visibility = appVisibility
        settings.kiwishelf.alignment = alignment
        let content = app(settings, windows: windows)
        let plans = core.shelfPlans(
            visible: CGRect(x: 0, y: 0, width: width, height: 1000),
            settings: settings,
            mode: content.space.mode,
            spaceItems: items(),
            app: content,
            pocket: false,
            drawn: { $0.drawnAtRest.union(drawn) }
        )
        #expect(plans.count == 1)
        return try #require(plans.first)
    }

    /// Where a bar's handle runs in `plan`: its slot of the resting
    /// arrangement, as `HidingShelves` reads it.
    private func handleSlot(
        _ bar: ShelfBar,
        _ plan: KiwiCore.ShelfPlan
    ) -> ShelfArrangement.Slot? {
        let placed = plan.revealed?.arrangement
        return bar == .space ? placed?.space : placed?.app
    }

    @Test(
        "a lone reveal lands under its handle",
        arguments: [KiwiShelf.Alignment.center, .start]
    )
    func landsUnderTheHandle(alignment: KiwiShelf.Alignment) throws {
        let rest = try plan([], alignment: alignment)
        let handle = try #require(handleSlot(.app, rest))
        // At rest the App handle runs beside the Space handle.
        #expect(handleSlot(.space, rest) != nil)
        let revealed = try plan([.app], alignment: alignment)
        #expect(revealed.arrangement.app == handle)
        #expect(revealed.arrangement.space == nil)
        #expect(handleSlot(.app, revealed) == handle)
        // The mirror: a lone Space reveal lands under its handle.
        let space = try plan([.space], alignment: alignment)
        #expect(space.arrangement.space == handleSlot(.space, rest))
        #expect(space.arrangement.app == nil)
    }

    @Test("revealing the second bar moves the first nowhere")
    func secondRevealMovesNothing() throws {
        let one = try plan([.app])
        let both = try plan([.app, .space])
        #expect(both.arrangement.app == one.arrangement.app)
        #expect(both.arrangement.space == handleSlot(.space, one))
    }

    @Test("one Auto bar and one Hidden: the Hidden bar joins it")
    func hiddenSiblingJoins() throws {
        // At rest the Auto App Bar is alone: its handle centres.
        let rest = try plan([], space: .hidden)
        let lone = try #require(handleSlot(.app, rest))
        #expect(handleSlot(.space, rest) == nil)
        #expect(lone.offset == 0 && lone.alignment == .center)
        // Revealed, the Hidden Space Bar joins it side by side, and
        // the App handle moves to its shared slot.
        let joined = try plan([.space], space: .hidden)
        let shared = try #require(handleSlot(.app, joined))
        #expect(shared != lone)
        #expect(joined.arrangement.space == handleSlot(.space, joined))
        #expect(joined.arrangement.app == nil)
    }

    @Test("both bars Hidden: one revealed lands alone and centred")
    func bothHiddenLandsAlone() throws {
        let one = try plan([.app], space: .hidden, app: .hidden)
        let slot = try #require(one.arrangement.app)
        #expect(slot.offset == 0 && slot.alignment == .center)
        #expect(handleSlot(.space, one) == nil)
    }

    @Test("a pair too wide for the edge caps the revealed share")
    func revealedShareIsCapped() throws {
        let narrow = try plan([.app], width: 400, windows: 12)
        let slot = try #require(narrow.arrangement.app)
        let need = try #require(narrow.needs[.app])
        #expect(slot.length < need)
        #expect(slot == handleSlot(.app, narrow))
        // Its Space sibling still holds its share as a handle.
        #expect(handleSlot(.space, narrow) != nil)
    }
}
