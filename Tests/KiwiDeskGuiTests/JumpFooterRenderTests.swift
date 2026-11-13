import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Windows footer lays out at every width without trapping
/// (#3271): its `ViewThatFits` candidates must carry distinct ids,
/// or SwiftUI stops the process ("child view IDs must be unique").
/// Main actor: it lays out a hosting view, a handful per test.
@Suite("Jump footer render (#3271)")
@MainActor
struct JumpFooterRenderTests {
    @Test("the Windows footer lays out from wide to narrow")
    func windowsFooterLaysOut() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        for held: NSEvent.ModifierFlags in [[], .shift, .option] {
            let footer = JumpFooter(scope: .windows, modifiers: held)
            for width: CGFloat in [1200, 640, 320, 120] {
                let host = NSHostingView(rootView: footer)
                host.frame = NSRect(x: 0, y: 0, width: width, height: 40)
                host.layoutSubtreeIfNeeded()
                #expect(host.fittingSize.height > 0)
            }
        }
    }
}
