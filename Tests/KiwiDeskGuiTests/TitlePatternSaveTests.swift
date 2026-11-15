import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A picked title still pending in the pattern field is part of what
/// a Save reads (#3340, #2584): ⌘S commits it before the draft is
/// read.
///
/// Main-actor spend: one hosted editor in an offscreen window and a
/// few short run-loop spins per test.
@Suite("A Save commits a pending title pattern (#3340)", .serialized)
@MainActor
struct TitlePatternSaveTests {
    private let app = "com.apple.textedit"

    private func hosted(
        _ model: SettingsModel
    ) throws -> NSWindow {
        var draft = TitlePatternDraft()
        draft.start(with: "Ohne Titel 2")
        let root = VStack {
            WindowTitleEditor(
                model: model,
                patterns: Binding(
                    get: {
                        FloatFacet.patterns(
                            model.config.floatRules,
                            app: app
                        )
                    },
                    set: {
                        model.config.floatRules =
                            FloatFacet.settingPatterns(
                                $0,
                                of: app,
                                in: model.config.floatRules
                            )
                    }
                ),
                app: app,
                caption: "",
                preview: { _ in EmptyView() },
                draft: draft
            )
            KeyboardSaveButton(model: model)
        }
        .environment(\.settingsCommitScope, ObjectIdentifier(model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
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

    @Test("the pending field holds focus once mounted")
    func fieldTakesFocus() throws {
        let model = makeTestModel()
        let window = try hosted(model)
        defer { window.orderOut(nil) }
        let editor = window.firstResponder as? NSTextView
        #expect(editor?.isFieldEditor == true)
        #expect(editor?.string == "Ohne Titel 2")
    }

    @Test("a commit request adds the pending pattern")
    func commitRequestAdds() throws {
        let model = makeTestModel()
        let window = try hosted(model)
        defer { window.orderOut(nil) }
        model.commitFocusedField()
        #expect(
            model.config.floatRules.contains("\(app):Ohne Titel 2")
        )
    }

    /// The device shape: a stored profile's Save, read back from
    /// disk, holds the pattern that was still pending.
    @Test("a Save writes the pending pattern and leaves no edit")
    func saveWritesPending() throws {
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
        let window = try hosted(model)
        defer { window.orderOut(nil) }
        model.performPrimarySave()
        spin()
        // A new rule lands in the edited profile's override.
        let prof = try core.profiles.read(name: "p")
        #expect(
            prof.floatRules?.rules["\(app):Ohne Titel 2"] == .some(true)
        )
        #expect(!model.isDirty)
    }
}
