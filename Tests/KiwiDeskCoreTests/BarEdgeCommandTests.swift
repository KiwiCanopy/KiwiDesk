import Foundation
import Testing

@testable import KiwiDeskCore

/// The edge verbs after #1731: each bar sets its own, the shelf's
/// retires naming the Space Bar's, and no layout sets the App
/// Bar's.
@MainActor
@Suite("Bar edge commands (#1731)")
struct BarEdgeCommandTests {
    @Test("each bar sets its own edge")
    func eachBarSetsItsEdge() {
        let core = makeTestCore()
        #expect(
            core.execute("space_bar.set_edge", args: [.string("left")])
                .isSuccess
        )
        #expect(
            core.execute("app_bar.set_edge", args: [.string("bottom")])
                .isSuccess
        )
        #expect(core.tiler.settings.spaceBarStyle.edge == .left)
        #expect(core.tiler.settings.appBarStyle.edge == .bottom)
        #expect(core.tiler.settings.sharedBarEdge == nil)
    }

    @Test("the retired edge verbs name their replacements")
    func retiredEdgeVerbs() {
        #expect(
            APIReference.retired["kiwishelf.set_edge"]
                == .some("space_bar.set_edge")
        )
        for layout in ["monocle", "scroll"] {
            #expect(
                APIReference.retired["\(layout).set_app_bar_edge"]
                    == .some("app_bar.set_edge")
            )
        }
        #expect(APIReference.retired["space_bar.set_edge"] == nil)
        #expect(APIReference.retired["app_bar.set_edge"] == nil)
    }

    /// Through the real dispatch, which refuses the verb before
    /// any override is written; `applyBarOverride`'s own refusal is
    /// the construction net behind it.
    @Test("a layout's App Bar takes no edge override")
    func noLayoutEdge() {
        let core = makeTestCore()
        let before = core.tiler.settings
        for layout in ["monocle", "scroll"] {
            let response = core.execute(
                "\(layout).set_app_bar_edge",
                args: [.string("left")]
            )
            #expect(!response.isSuccess)
            #expect(response.error?.contains("app_bar.set_edge") == true)
        }
        #expect(core.tiler.settings == before)
        var bar = LayoutAppBar()
        #expect(
            !core.applyBarOverride(
                field: "edge",
                [.string("left")],
                into: &bar
            ).isSuccess
        )
        #expect(bar == LayoutAppBar())
    }
}
