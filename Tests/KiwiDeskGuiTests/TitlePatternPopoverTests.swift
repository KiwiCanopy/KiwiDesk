import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The title popover (#3373): it opens on its seed with the field
/// focused, adds through its own confirm — Return or Add — and never
/// through a blur or a Save's commit request, which an outside click
/// dismissing it would otherwise read as Add.
///
/// Main-actor spend: one hosted popover body in an offscreen window
/// per test and a few short run-loop spins.
@Suite("Title popover (#3373)", .serialized)
@MainActor
struct TitlePatternPopoverTests {
    private final class Added { var patterns: [String] = [] }

    private func hosted(
        _ model: SettingsModel,
        seed: String,
        refusing refused: String? = nil,
        into added: Added
    ) throws -> NSWindow {
        let root = TitlePatternPopover(
            model: model,
            app: "com.apple.textedit",
            covered: [],
            seed: seed,
            refusal: { $0 == refused ? "taken" : nil },
            onCommit: { added.patterns.append($0) },
            onCancel: {}
        )
        .environment(\.settingsCommitScope, ObjectIdentifier(model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: root)
        window.contentView?.layoutSubtreeIfNeeded()
        spin()
        let field = try #require(Self.textField(in: window.contentView))
        #expect(window.makeFirstResponder(field))
        spin()
        return window
    }

    private static func textField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable {
            return field
        }
        for sub in view.subviews {
            if let found = textField(in: sub) { return found }
        }
        return nil
    }

    private func spin() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    @Test("the field opens on its seed, focused")
    func opensOnTheSeed() throws {
        let added = Added()
        let window = try hosted(
            makeTestModel(),
            seed: "Ohne Titel 2",
            into: added
        )
        defer { window.orderOut(nil) }
        let editor = window.firstResponder as? NSTextView
        #expect(editor?.isFieldEditor == true)
        #expect(editor?.string == "Ohne Titel 2")
    }

    @Test("Return adds the trimmed pattern")
    func returnAdds() throws {
        let added = Added()
        let window = try hosted(
            makeTestModel(),
            seed: " Work ",
            into: added
        )
        defer { window.orderOut(nil) }
        (window.firstResponder as? NSTextView)?.insertNewline(nil)
        spin()
        #expect(added.patterns == ["Work"])
    }

    @Test("a refused pattern is not added")
    func refusalBlocks() throws {
        let added = Added()
        let window = try hosted(
            makeTestModel(),
            seed: "Work",
            refusing: "Work",
            into: added
        )
        defer { window.orderOut(nil) }
        (window.firstResponder as? NSTextView)?.insertNewline(nil)
        spin()
        #expect(added.patterns.isEmpty)
    }

    @Test("a Save's commit request adds nothing")
    func commitRequestIsNoAdd() throws {
        let added = Added()
        let model = makeTestModel()
        let window = try hosted(model, seed: "Work", into: added)
        defer { window.orderOut(nil) }
        model.commitFocusedField()
        spin()
        #expect(added.patterns.isEmpty)
    }
}
