import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// An alert whose Cancel is the default answers Return AND Escape
/// with Cancel (#2826): Return moves onto Cancel, and a key-down
/// watch hands back the Escape that move takes from it.
@Suite("Cancel-default alerts (#2826)")
@MainActor
struct CancelDefaultTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func key(
        _ code: UInt16,
        _ flags: NSEvent.ModifierFlags = []
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: code
            )
        )
    }

    @Test("Return moves from the confirm onto Cancel")
    func returnOnCancel() {
        let alert = NSAlert()
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        CancelDefault.prepare(alert)
        #expect(alert.buttons[0].keyEquivalent.isEmpty)
        #expect(alert.buttons[1].keyEquivalent == "\r")
    }

    @Test("Escape is a bare Escape press, Caps Lock or not")
    func escapeKey() throws {
        #expect(CancelDefault.isEscape(try key(53)))
        #expect(CancelDefault.isEscape(try key(53, .capsLock)))
        #expect(!CancelDefault.isEscape(try key(53, .command)))
        #expect(!CancelDefault.isEscape(try key(53, .shift)))
        #expect(!CancelDefault.isEscape(try key(36)))
    }

    @Test("both runners watch Escape and press Cancel")
    func runnersWatchEscape() throws {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/CancelDefault.swift"
            )
        )
        #expect(source.occurrences(of: "prepare(alert)") == 2)
        #expect(source.occurrences(of: "watchEscape(alert)") == 2)
        #expect(source.occurrences(of: "NSEvent.removeMonitor(") == 2)
        #expect(source.contains("let cancel = alert.buttons[1]"))
        #expect(source.contains("cancel.performClick(nil)"))
        // Only the alert's own Escape, and the app-modal watch
        // lives until `runModal` returns, not before it starts.
        #expect(
            source.contains(
                "guard event.window === alert.window, isEscape(event)"
            )
        )
        #expect(
            source.occurrences(
                of: "defer { if let escape { NSEvent.removeMonitor(escape) } }"
            ) == 1
        )
    }

    /// Clearing an alert button's Return is the tell of a
    /// cancel-default alert spelled by hand, which drops Escape.
    @Test("no alert moves Return onto Cancel by hand")
    func noHandSpelledDefault() throws {
        let tree = Self.root.appendingPathComponent("Sources/KiwiDesk")
        var hits: [String] = []
        let files = try SourceScan.swiftSources(under: tree)
        #expect(!files.isEmpty)
        for file in files
        where file.lastPathComponent
            != "CancelDefault.swift"
        {
            let text = try SourceScan.strippedSource(at: file)
            if text.contains(".keyEquivalent = \"\"") {
                hits.append(file.lastPathComponent)
            }
        }
        #expect(hits.isEmpty, "\(hits)")
    }

    @Test("every cancel-default alert runs through the door")
    func sitesTakeTheDoor() throws {
        let sites = [
            "AppDelegate+BarMenus.swift": "CancelDefault.runModal(alert)",
            "ConfigIssuesWindow.swift": "CancelDefault.runModal(alert)",
            "Settings/Components/General/RestoreConfirm.swift":
                "CancelDefault.beginSheet(alert",
        ]
        for (path, needle) in sites {
            let text = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Sources/KiwiDesk/\(path)"
                )
            )
            #expect(text.contains(needle), "\(path)")
        }
    }
}
