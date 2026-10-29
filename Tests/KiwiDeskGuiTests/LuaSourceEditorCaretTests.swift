import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// Typing in a Lua body keeps its caret (#2768): an update carrying
/// a body the view itself produced arrives late and is dropped, a
/// write from outside lands, and any write keeps the selection.
@MainActor
@Suite("Lua source editor caret")
struct LuaSourceEditorCaretTests {
    private final class Draft {
        var body: String

        init(_ body: String) {
            self.body = body
        }
    }

    private static func editor(
        _ body: String
    ) -> (NSTextView, LuaSourceEditor.Coordinator) {
        let draft = Draft(body)
        let coordinator = LuaSourceEditor.Coordinator(
            text: Binding(get: { draft.body }, set: { draft.body = $0 })
        )
        let textView = NSTextView()
        textView.string = body
        return (textView, coordinator)
    }

    private static func type(
        _ letter: String,
        in textView: NSTextView,
        _ coordinator: LuaSourceEditor.Coordinator
    ) {
        textView.insertText(letter, replacementRange: textView.selectedRange())
        coordinator.textDidChange(
            Notification(name: NSText.didChangeNotification, object: textView)
        )
    }

    @Test("a render behind the typing leaves text and caret alone")
    func lateEchoDropped() {
        let opened = "local a = 1\nlocal b = 2"
        let (textView, coordinator) = Self.editor(opened)
        textView.setSelectedRange(NSRange(location: 7, length: 0))
        Self.type("x", in: textView, coordinator)
        let once = textView.string
        Self.type("y", in: textView, coordinator)
        let twice = textView.string
        coordinator.apply(opened, to: textView)
        coordinator.apply(once, to: textView)
        #expect(textView.string == twice)
        #expect(textView.selectedRange() == NSRange(location: 9, length: 0))
        coordinator.apply(twice, to: textView)
        #expect(textView.selectedRange() == NSRange(location: 9, length: 0))
    }

    @Test("a write from outside lands, caret kept")
    func outsideWriteLands() {
        let (textView, coordinator) = Self.editor("abcdef")
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        Self.type("x", in: textView, coordinator)
        coordinator.apply("reverted", to: textView)
        #expect(textView.string == "reverted")
        #expect(textView.selectedRange() == NSRange(location: 4, length: 0))
    }

    /// The order the device shows: a keystroke, the render that
    /// matches it, then a Revert to the opened body.
    @Test("a revert to the opened body lands once a render matched")
    func revertAfterMatchLands() {
        let opened = "abcdef"
        let (textView, coordinator) = Self.editor(opened)
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        Self.type("x", in: textView, coordinator)
        coordinator.apply(textView.string, to: textView)
        coordinator.apply(opened, to: textView)
        #expect(textView.string == opened)
    }

    @Test("a shorter body clamps the selection into it")
    func shorterBodyClamps() {
        let textView = NSTextView()
        textView.string = "abcdef"
        textView.setSelectedRange(NSRange(location: 1, length: 4))
        LuaSourceEditor.replace(textView, with: "abc")
        #expect(textView.selectedRange() == NSRange(location: 1, length: 2))
    }

    /// The representable routes every SwiftUI value through the
    /// coordinator, never a `string` write of its own.
    @Test("updateNSView writes only through the coordinator")
    func updateRoutesThroughCoordinator() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Lua/"
                            + "LuaEditorTab.swift"
                    ),
                encoding: .utf8
            )
        ).filter { !$0.isWhitespace }
        let start = try #require(source.range(of: "funcupdateNSView("))
        let end = try #require(
            source.range(
                of: "staticfuncreplace(",
                range: start.upperBound..<source.endIndex
            )
        )
        let update = source[start.upperBound..<end.lowerBound]
        #expect(update.contains("context.coordinator.apply(text,to:textView)"))
        #expect(update.contains("context.coordinator.text=$text"))
        #expect(!update.contains(".string="))
    }
}
