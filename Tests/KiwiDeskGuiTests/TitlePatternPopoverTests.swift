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
/// per test, run-loop spins until each awaited state, and a fixed
/// 0.15 s drain under each negative.
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
            preview: { _ in EmptyView() },
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
        spin { Self.textField(in: window.contentView) != nil }
        let field = try #require(Self.textField(in: window.contentView))
        #expect(window.makeFirstResponder(field))
        spin {
            (window.firstResponder as? NSTextView)?.isFieldEditor == true
        }
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

    /// Runs the main run loop until `done` holds; the deadline
    /// only bounds a hang (tests.md ▸ await the handle, #3442).
    private func spin(until done: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !done(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// A negative's gap: nothing is awaited, so the run loop runs a
    /// fixed beat for a late effect to land in.
    private func drain() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    /// The harness focuses the field itself; this holds the seed.
    @Test("the field opens on its seed")
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
        spin { !added.patterns.isEmpty }
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
        drain()
        #expect(added.patterns.isEmpty)
    }

    @Test("a Save's commit request adds nothing")
    func commitRequestIsNoAdd() throws {
        let added = Added()
        let model = makeTestModel()
        let window = try hosted(model, seed: "Work", into: added)
        defer { window.orderOut(nil) }
        model.commitFocusedField()
        drain()
        #expect(added.patterns.isEmpty)
    }

    @Test("a blur adds nothing")
    func blurIsNoAdd() throws {
        let added = Added()
        let window = try hosted(makeTestModel(), seed: "Work", into: added)
        defer { window.orderOut(nil) }
        #expect(window.firstResponder is NSTextView)
        window.makeFirstResponder(nil)
        drain()
        #expect(!(window.firstResponder is NSTextView))
        #expect(added.patterns.isEmpty)
    }

    /// The live check rides in the popover as the pattern is typed
    /// (#123, #3373): each host hands its engine-backed preview the
    /// popover's pending text, and the popover draws it.
    @Test("each popover draws its preview of the typed pattern")
    func previewsTakeThePending() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        func squashed(_ path: String) throws -> String {
            try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            )
            .split(whereSeparator: \.isWhitespace).joined()
        }
        let settings = "Sources/KiwiDesk/Settings/"
        #expect(
            try squashed(
                settings + "Components/Common/TitlePatternPopover.swift"
            ).contains("preview(draft.text)")
        )
        let space = try squashed(
            settings + "Sections/AppRuleSpaceRow+Scope.swift"
        )
        #expect(
            space.contains(
                "space:SpaceRuleRows.space(of:row,in:model.config),"
                    + "pending:pending)"
            )
        )
        #expect(
            space.contains(
                "?row:SpaceRuleRow(app:row.app,fragment:\"\"),"
            )
        )
        #expect(
            try squashed(
                settings + "Components/Common/WindowTitleEditor.swift"
            ).contains("preview:preview,")
        )
        #expect(
            try squashed(settings + "Sections/AppRuleFloatRow.swift")
                .contains(
                    "AppRuleMatchPreview(model:model,app:app,pending:pending)"
                )
        )
    }
}
