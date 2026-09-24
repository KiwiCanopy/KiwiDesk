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
                "monocle.set_app_bar_active_indicator",
                args: [.string("edge_mark")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "monocle.set_app_bar_content",
                args: [.string("icon_and_title")]
            ).isSuccess
        )
    }

    @Test("Hover default is a shade off the highlight")
    func hoverDefault() {
        let bar = KiwiShelf()
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
        // Gap left the indicator (#1517); the refusal lists
        // what remains.
        let gap = core.execute(
            "monocle.set_app_bar_active_indicator",
            args: [.string("gap")]
        )
        #expect(!gap.isSuccess)
        #expect(gap.error?.contains("edge_mark") == true)
    }

    @Test("A shared field's override is retired, naming the shelf")
    func sharedOverrideRetired() {
        let core = makeCore()
        let response = core.execute(
            "monocle.set_app_bar_edge",
            args: [.string("left")]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error?.contains("kiwishelf.set_edge")
                == true
        )
        // Colours are the shelf's too (#1517).
        let colour = core.execute(
            "monocle.set_app_bar_highlight_color",
            args: [.string("#123456")]
        )
        #expect(!colour.isSuccess)
        #expect(
            colour.error?.contains("kiwishelf.set_highlight_color")
                == true
        )
    }
}
