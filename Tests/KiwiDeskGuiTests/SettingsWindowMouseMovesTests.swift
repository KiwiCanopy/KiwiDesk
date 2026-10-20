import AppKit
import Testing

@testable import KiwiDesk

/// The Settings window takes mouse-moved events for hover focus
/// (#2378) and drops them while a popover hangs from it (#2501):
/// left on, the flag makes SwiftUI hover in that popover flicker
/// and stick to a row the pointer left. Neither window is ordered
/// in.
@Suite("Settings window mouse moves")
@MainActor
struct SettingsWindowMouseMovesTests {
    private func pair() -> (SettingsWindow, NSWindow) {
        let settings = SettingsWindow(
            contentRect: NSRect(x: -4000, y: -4000, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        settings.syncMouseMoves()
        let popover = NSPanel(
            contentRect: NSRect(x: -4000, y: -4000, width: 50, height: 50),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        return (settings, popover)
    }

    @Test("it takes mouse moves while nothing hangs from it")
    func takesMovesAlone() {
        let (settings, _) = pair()
        #expect(settings.acceptsMouseMovedEvents)
    }

    @Test("a popover hanging from it turns the moves off")
    func popoverTurnsMovesOff() {
        let (settings, popover) = pair()
        settings.addChildWindow(popover, ordered: .above)
        defer {
            settings.removeChildWindow(popover)
            popover.orderOut(nil)
        }
        #expect(!settings.acceptsMouseMovedEvents)
    }

    /// Hover focus leaving Settings needs them back (#2378).
    @Test("the popover leaving turns them back on")
    func popoverLeavingRestores() {
        let (settings, popover) = pair()
        settings.addChildWindow(popover, ordered: .above)
        settings.removeChildWindow(popover)
        popover.orderOut(nil)
        #expect(settings.acceptsMouseMovedEvents)
    }

    /// Derived from the children, so two overlapping popovers
    /// cannot leave it off once both are gone.
    @Test("two popovers in turn leave the moves on once both go")
    func overlappingPopovers() {
        let (settings, first) = pair()
        let (_, second) = pair()
        settings.addChildWindow(first, ordered: .above)
        settings.addChildWindow(second, ordered: .above)
        settings.removeChildWindow(first)
        #expect(!settings.acceptsMouseMovedEvents)
        settings.removeChildWindow(second)
        first.orderOut(nil)
        second.orderOut(nil)
        #expect(settings.acceptsMouseMovedEvents)
    }

    /// A detach that skipped the override costs nothing past the
    /// window's next key: hover focus leaving needs the moves.
    @Test("becoming key re-derives the moves")
    func keyReDerives() {
        let (settings, _) = pair()
        settings.acceptsMouseMovedEvents = false
        settings.becomeKey()
        #expect(settings.acceptsMouseMovedEvents)
    }

    /// The doc's claim that a popover is the one child Settings
    /// gets: no GUI file attaches a window by hand, so a lasting
    /// child cannot switch hover focus's moves off unseen.
    @Test("nothing in the GUI attaches a child or writes the flag")
    func noHandAttachedChildren() throws {
        let tree = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let files = try SourceScan.swiftSources(under: tree)
        #expect(files.count > 100)
        var home = false
        for file in files {
            let source = try SourceScan.blankedSource(at: file)
            // Attaching a child, or writing the flag beside the one
            // derivation, both switch the moves unseen.
            let attaches =
                source.contains("addChildWindow(")
                || source.contains(".parent =")
                || source.contains("acceptsMouseMovedEvents =")
            if file.lastPathComponent == "SettingsWindow.swift" {
                home = attaches
                continue
            }
            #expect(!attaches, "\(file.lastPathComponent)")
        }
        // The scan sees the overrides it exempts.
        #expect(home)
    }
}
