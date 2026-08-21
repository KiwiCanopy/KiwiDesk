import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

@Suite("Monocle commands", .serialized)
@MainActor
struct MonocleCommandTests {
    @Test("monocle.* setters update the settings")
    func setters() {
        let core = makeCore()
        #expect(
            core.execute(
                "monocle.set_orientation",
                args: [.string("vertical")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.orientation
                == .vertical
        )
        // Default is `stack` (#881) — today's behavior — and
        // the setter takes the park opt-in.
        #expect(
            core.tiler.settings.monocle.hideStyle == .stack
        )
        #expect(
            core.execute(
                "monocle.set_hide_style",
                args: [.string("park")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.hideStyle == .park
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_background_style",
                args: [.string("plain")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.backgroundStyle
                == .plain
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_active_indicator",
                args: [.string("gap")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_content",
                args: [.string("icon_and_title")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_item_size",
                args: [.number(150)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.itemSize == 150
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_highlight_color",
                args: [.string("#123456")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.highlightColor
                == "#123456"
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_hover_fill_color",
                args: [.string("#4E9F3D40")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.hoverFillColor
                == "#4E9F3D40"
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_hover_item_color",
                args: [.string("#101010")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.appBar.hoverItemColor
                == "#101010"
        )
    }

    @Test("Hover default is a shade off the highlight")
    func hoverDefault() {
        let bar = AppBarStyle()
        #expect(bar.hoverFillColor != bar.highlightColor)
    }

    @Test("Invalid values are rejected")
    func validation() {
        let core = makeCore()
        #expect(
            !core.execute(
                "monocle.set_orientation",
                args: [.string("diagonal")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_hide_style",
                args: [.string("hide")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle.hideStyle == .stack
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("middle")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_item_size",
                args: [.string("wide")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "monocle.set_app_bar_item_color",
                args: [.string("red")]
            ).isSuccess
        )
    }

    @Test("Edge takes the four edges, rejects start/end")
    func edgeTokens() {
        let core = makeCore()
        // Absolute tokens are stored as-is (#293) — the layout
        // orientation plays no part.
        #expect(
            core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("left")]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.monocle
                .resolvedBar(global: AppBarStyle()).edge == .left
        )
        // The old axis-relative tokens are no longer valid.
        #expect(
            !core.execute(
                "monocle.set_app_bar_edge",
                args: [.string("start")]
            ).isSuccess
        )
    }
}
