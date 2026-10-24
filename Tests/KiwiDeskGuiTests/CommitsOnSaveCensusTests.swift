import Foundation
import Testing

/// Every Settings field that keeps its typing local commits through
/// the one `commitsOnSave`, so a Save or a leave hears it (#2584),
/// and every reader of the draft that a typed value must reach asks
/// for the commit first.
@Suite("Commit-on-save census (#2584)")
struct CommitsOnSaveCensusTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let home = "CommitsOnSave.swift"

    /// Files with a focusable text field that commit through their
    /// own confirm, never on blur: searches and add rows.
    private static let exempt: [String: String] = [
        "JumpPanelView.swift": "KiwiHub's search, no draft",
        "FontFamilyPicker.swift": "a searchable picker; Return picks",
        "AppPickerButton.swift": "an app search; Return adds",
        "LayerStripEditor.swift": "the add-layer field; Return adds",
    ]

    private func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    private func guiFiles() throws -> [(name: String, text: String)] {
        let dir = Self.root.appendingPathComponent("Sources/KiwiDesk")
        let urls = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: nil
        )?.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        let files = try (urls ?? []).map {
            (
                name: $0.lastPathComponent,
                text: try SourceScan.strippedSource(at: $0)
                    .split(whereSeparator: \.isWhitespace).joined()
            )
        }
        #expect(files.count > 100, "scan read the GUI tree")
        return files
    }

    /// The subject is the field, not a spelling: a file with a
    /// focus state and a text field joins the modifier or names
    /// why not. Trade: it asks per file, so a second field added to
    /// a file that already joins (or is exempt) passes unseen.
    @Test("Every focusable text field joins or is exempt")
    func everyFieldJoins() throws {
        let files = try guiFiles()
        let fields = files.filter {
            $0.text.contains("@FocusState") && $0.text.contains("TextField(")
        }
        let joined = fields.filter { $0.text.contains(".commitsOnSave($") }
        #expect(joined.count >= 6)
        for field in fields where !field.text.contains(".commitsOnSave($") {
            #expect(
                Self.exempt[field.name] != nil,
                "\(field.name) has a text field outside commitsOnSave"
            )
        }
        for name in Self.exempt.keys {
            #expect(
                fields.contains { $0.name == name },
                "\(name) is exempt but has no focusable text field"
            )
        }
    }

    /// A blur commit spelled by hand beside the modifier.
    @Test("No field commits on blur beside the one modifier")
    func noHandBlurCommit() throws {
        for file in try guiFiles() where file.name != Self.home {
            #expect(
                file.text.occurrences(of: ".onSubmit(commit)") == 0,
                "\(file.name) commits on Return beside commitsOnSave"
            )
            #expect(
                Self.blurCommits(in: file.text) == 0,
                "\(file.name) commits on blur beside commitsOnSave"
            )
        }
    }

    private static func blurCommits(in text: String) -> Int {
        let pattern = try? NSRegularExpression(
            pattern: #"if![A-Za-z_.]+\{commit\(\)\}"#
        )
        return pattern?.numberOfMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text)
        ) ?? 0
    }

    /// The needle sees the shape it guards: the modifier's own body.
    @Test("The blur needle matches the modifier it replaced")
    func needleSeesTheShape() throws {
        let home = try flat("Sources/KiwiDesk/Settings/" + Self.home)
        #expect(Self.blurCommits(in: home) == 1)
        // Return commits too, and only through the modifier.
        #expect(home.occurrences(of: ".onSubmit(commit)") == 1)
    }

    @Test("Each draft reader asks for the commit first")
    func readersAskFirst() throws {
        let dir = "Sources/KiwiDesk/"
        for (file, head) in [
            (
                "Settings/SettingsModel+SaveAction.swift",
                "funcperformPrimarySave(){commitFocusedField()"
            ),
            (
                "Settings/SettingsModel+Sync.swift",
                "->SyncRefusal?{commitFocusedField()ifisDirty{"
            ),
            (
                "Settings/SettingsModel+Leave.swift",
                "commitFocusedField()guardisDirtyelse{returnproceed()}"
            ),
            (
                "Settings/SettingsModel+Discard.swift",
                "commitFocusedField()guardisDirtyelse{returnaction()}"
            ),
            (
                "Settings/SettingsWindowController.swift",
                "model.commitFocusedField()guardmodel.isDirtyelse{returntrue}"
            ),
            (
                "AppDelegate+Quit.swift",
                "dashboard.commitFocusedField()"
                    + "guarddashboard.quitAsksAboutDraftelse{"
            ),
        ] {
            #expect(
                try flat(dir + file).occurrences(of: head) == 1,
                "\(file) reads the draft before the commit"
            )
        }
        let keyboard = try flat(dir + "Settings/" + Self.home)
        #expect(
            keyboard.occurrences(
                of: "funcsaveFromKeyboard(){commitFocusedField()"
                    + "guardprimarySaveEnabledelse{return}"
                    + "performPrimarySave()}"
            ) == 1
        )
    }

    /// ⌘S rides the root, which is mounted whatever the draft, and
    /// nowhere else.
    @Test("⌘S is the root's, once")
    func keyboardSaveOnTheRoot() throws {
        let view = try flat("Sources/KiwiDesk/Settings/SettingsView.swift")
        // The scope a field answers by is the root's, set once.
        #expect(
            view.occurrences(
                of: ".environment(\\.settingsCommitScope,"
                    + "ObjectIdentifier(model))"
            ) == 1
        )
        #expect(
            view.occurrences(
                of: ".background(KeyboardSaveButton(model:model))"
            )
                == 1
        )
        let all = try guiFiles()
        let shortcuts = all.map {
            $0.text.occurrences(of: ".keyboardShortcut(\"s\")")
        }
        #expect(shortcuts.reduce(0, +) == 1)
    }
}
