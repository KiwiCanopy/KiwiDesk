import AppKit
import Testing

@testable import KiwiDeskCore

/// A dropped overlay takes its panel off screen (#1868). AppKit
/// keeps an ordered-in window alive after its owner is gone, so
/// without the overlays' `isolated deinit` every test core that
/// drew a shelf or a sticky mark left a transparent panel up for
/// the rest of the run — hundreds by the end, and WindowServer
/// answered every later call slower.
@MainActor
@Suite("A dropped overlay takes its panel off screen (#1868)")
struct OverlayPanelReleaseTests {
    /// The panels `make` put on screen, and how many of them are
    /// still on screen once its overlay is dropped. Synchronous on
    /// the main actor, so no other suite's window lands in between.
    private func panels(
        shownBy make: () -> AnyObject
    ) -> (shown: Int, left: Int) {
        let app = NSApplication.shared
        let before = Set(app.windows.map(ObjectIdentifier.init))
        var mine: [NSWindow] = []
        // The overlay lives exactly as long as this scope.
        withExtendedLifetime(make()) {
            mine = app.windows.filter {
                !before.contains(ObjectIdentifier($0)) && $0.isVisible
            }
        }
        return (mine.count, mine.filter(\.isVisible).count)
    }

    @Test("a shelf")
    func shelf() {
        let result = panels {
            let overlay = ShelfOverlay()
            overlay.show(
                strip: CGRect(x: 0, y: 0, width: 600, height: 30),
                edge: .top,
                shelf: KiwiShelf(),
                sheen: 0,
                sections: [
                    ShelfOverlay.Section(
                        view: NSView(),
                        slot: CGRect(x: 0, y: 0, width: 600, height: 30),
                        plate: .zero,
                        content: .zero
                    )
                ]
            )
            return overlay
        }
        #expect(result.shown == 1)
        #expect(result.left == 0)
    }

    @Test("a sticky mark")
    func stickyMark() {
        let result = panels {
            let overlay = StickyMarkOverlay(window: 1)
            overlay.update(
                frame: CGRect(x: 100, y: 100, width: 400, height: 300)
            )
            return overlay
        }
        #expect(result.shown == 1)
        #expect(result.left == 0)
    }
}
