import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

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

    private func typed(
        _ model: SettingsModel = makeTestModel()
    ) throws -> Typed {
        // The field and ⌘S as the Settings root mounts them.
        let row = VStack {
            StepperRow(
                label: "Delay",
                value: Binding(
                    get: { model.config.settings.mouse.hoverFocusDelayMS },
                    set: { model.config.settings.mouse.hoverFocusDelayMS = $0 }
                ),
                in: 0...5000
            )
            KeyboardSaveButton(model: model)
        }
        .environment(\.settingsCommitScope, ObjectIdentifier(model))
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

    /// A typed value alone is an unsaved edit, so closing asks —
    /// through the window's own gate, ahead of its dirty read.
    @Test("Closing with only a typed value asks first")
    func closeAsks() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        let controller = SettingsWindowController(model: typed.model)
        #expect(!controller.windowShouldClose(typed.window))
        #expect(typed.model.isDirty)
    }

    /// ⌘S reaches the root's button as a key event, commits, then
    /// runs the Save: with no profile live, Save as New's prompt.
    @Test("⌘S commits the typed value, then saves")
    func keyboardSaveCommitsAndSaves() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        #expect(try pressSave(in: typed.window))
        #expect(typed.model.config.settings.mouse.hoverFocusDelayMS == 1234)
        #expect(typed.model.newProfileNamingRequested)
    }

    /// A stored profile's Save is greyed on a clean draft, so ⌘S
    /// commits before it asks whether there is anything to save.
    @Test("⌘S saves a typed value that is the one edit")
    func keyboardSaveOnAGreyedSave() throws {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        _ = try core.profiles.write(
            Profile(
                name: "p",
                monitorSets: [MonitorSet(monitors: ["Away:100x100"])],
                spaces: [SpaceID("1")],
                spaceModes: [SpaceID("1"): .bsp],
                settings: TilingSettings()
            )
        )
        model.reload()
        model.selectEditTarget("p")
        #expect(model.primarySaveAction == .updateStoredProfile)
        let typed = try typed(model)
        defer { typed.window.orderOut(nil) }
        #expect(!model.primarySaveEnabled)
        #expect(try pressSave(in: typed.window))
        // Committed although Save was greyed; that the Save then
        // runs is the census's pin on `saveFromKeyboard`'s body.
        #expect(model.config.settings.mouse.hoverFocusDelayMS == 1234)
        #expect(model.primarySaveEnabled || !model.isDirty)
    }

    private func pressSave(in window: NSWindow) throws -> Bool {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "s",
                charactersIgnoringModifiers: "s",
                isARepeat: false,
                keyCode: 1
            )
        )
        return window.performKeyEquivalent(with: event)
    }

    /// Another model's request commits nothing here: a field
    /// answers its own window's Save.
    @Test("A request from another model is ignored")
    func scopedToItsModel() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        makeTestModel().commitFocusedField()
        #expect(typed.model.config.settings.mouse.hoverFocusDelayMS != 1234)
    }

    @Test("The commit leaves the caret where it was")
    func caretStays() throws {
        let typed = try typed()
        defer { typed.window.orderOut(nil) }
        typed.model.performPrimarySave()
        #expect(typed.window.firstResponder === typed.editor)
    }
}
