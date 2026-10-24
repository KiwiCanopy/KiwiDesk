import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A value still being typed in a field that commits on blur is part
/// of what a Save or a leave reads (#2584): the request to commit
/// reaches the focused field before the draft is read, whichever
/// window is key and without moving the caret.
///
/// Main-actor spend: one hosted row in an offscreen window and a few
/// short run-loop spins per test.
@Suite("A Save commits the field being typed in (#2584)", .serialized)
@MainActor
struct SaveCommitsFocusedFieldTests {
    /// A hosted `StepperRow` bound to the draft's hover delay, with
    /// "1234" typed into its field and the caret still there.
    private struct Typed {
        let model: SettingsModel
        let window: NSWindow
        let editor: NSTextView
    }

    private func typed() throws -> Typed {
        let model = makeTestModel()
        let row = StepperRow(
            label: "Delay",
            value: Binding(
                get: { model.config.settings.mouse.hoverFocusDelayMS },
                set: { model.config.settings.mouse.hoverFocusDelayMS = $0 }
            ),
            in: 0...5000
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: row)
        window.contentView?.layoutSubtreeIfNeeded()
        spin()
        let field = try #require(Self.textField(in: window.contentView))
        #expect(window.makeFirstResponder(field))
        spin()
        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.isFieldEditor)
        editor.selectAll(nil)
        editor.insertText("1234", replacementRange: editor.selectedRange())
        spin()
        // The precondition the bug needs: typed, not yet committed.
        #expect(model.config.settings.mouse.hoverFocusDelayMS != 1234)
        return Typed(model: model, window: window, editor: editor)
    }

    private func spin() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
    }

    private static func textField(in view: NSView?) -> NSTextField? {
        guard let view else { return nil }
        if let field = view as? NSTextField, field.isEditable { return field }
        for sub in view.subviews {
            if let found = textField(in: sub) { return found }
        }
        return nil
    }

    @Test("A Save reads the typed value")
    func saveCommitsTheField() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        typed.model.performPrimarySave()
        #expect(typed.model.config.settings.mouse.hoverFocusDelayMS == 1234)
    }

    /// A typed value alone is an unsaved edit, so a quit asks.
    @Test("A leave with only a typed value asks first")
    func leaveAsks() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        var proceeded = false
        typed.model.leavingDraft(
            .quit,
            proceed: { proceeded = true },
            cancel: {}
        )
        #expect(!proceeded)
        #expect(typed.model.isDirty)
    }

    /// ⌘S commits first, then runs the Save the commit made due:
    /// with no profile live that is Save as New's naming prompt.
    @Test("⌘S commits the typed value, then saves")
    func keyboardSaveCommitsAndSaves() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        #expect(typed.model.primarySaveAction == .saveAsNewProfile)
        typed.model.saveFromKeyboard()
        #expect(typed.model.config.settings.mouse.hoverFocusDelayMS == 1234)
        #expect(typed.model.newProfileNamingRequested)
    }

    @Test("The commit leaves the caret where it was")
    func caretStays() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        typed.model.performPrimarySave()
        #expect(typed.window.firstResponder === typed.editor)
    }
}
