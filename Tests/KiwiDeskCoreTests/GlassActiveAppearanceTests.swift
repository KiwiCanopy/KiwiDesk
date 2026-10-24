import AppKit
import Testing

@testable import KiwiDeskCore

/// The key-window glass look (#2569): the listed panels answer
/// AppKit's private question YES once installed, and no other panel
/// does — never `NSPanel` itself, which every panel shares.
@Suite("Glass panels answer the active question")
@MainActor
struct GlassActiveAppearanceTests {
    private var selector: Selector {
        NSSelectorFromString(GlassActiveAppearance.privateSelector)
    }

    private func answers(_ panel: NSPanel) -> Bool {
        guard panel.responds(to: selector),
            let imp = panel.method(for: selector)
        else { return false }
        typealias Ask = @convention(c) (AnyObject, Selector) -> Bool
        return unsafeBitCast(imp, to: Ask.self)(panel, selector)
    }

    private func make(_ type: NSPanel.Type) -> NSPanel {
        type.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
    }

    @Test("a plate's panel answers its own switch on every ask")
    func platePanelFollowsItsSwitch() {
        let plate = ActiveGlassPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        #expect(answers(plate))
        plate.wearsActiveLook = false
        #expect(!answers(plate))
        plate.wearsActiveLook = true
        #expect(answers(plate))
    }

    @Test("a panel outside the list keeps AppKit's own answer")
    func otherPanelsKeepTheirs() {
        GlassActiveAppearance.install()
        #expect(
            !GlassActiveAppearance.classes.contains { $0 == NSPanel.self }
        )
        let plain = make(NSPanel.self)
        // AppKit's own answer for a panel that is not key.
        #expect(!answers(plain) || !plain.isKeyWindow)
        #expect(
            plain.method(for: selector)
                != make(ShelfPanel.self).method(for: selector)
        )
    }
}
