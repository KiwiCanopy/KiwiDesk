import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Key sequences card's one-line rows (#3162 ▸ Ruling and its
/// amendment): one container per key, told apart by its face; App…
/// writes the Apps section's binding; a branch carries a symbol the
/// hint panel draws, `folder` by default.
@Suite("Key sequence card rows (#3162)")
@MainActor
struct KeySequenceCardRowsTests {
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/"
        + "Keybindings/Sequences/"

    private static func source(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(dir + name)
        )
    }

    private static func flat(_ text: String) -> String {
        text.filter { !$0.isWhitespace }
    }

    @Test("App… writes the Apps section's binding and keeps its action")
    func appKeyWritesTheAppsBinding() {
        let key = SequenceTree.newEndKey(combo: "s")
        let app = SequenceTree.appKey(
            key,
            bundleID: "com.apple.safari",
            name: "Safari"
        )
        #expect(app.id == key.id)
        #expect(app.kind == .application)
        #expect(app.lua == KeybindingCatalog.appCommand("com.apple.safari"))
        #expect(app.combo == "s")
        var gather = app
        gather.lua = KeybindingCatalog.appCommand(
            "com.apple.safari",
            action: .gather
        )
        let moved = SequenceTree.appKey(
            gather,
            bundleID: "com.apple.mail",
            name: "Mail"
        )
        #expect(
            moved.lua
                == KeybindingCatalog.appCommand(
                    "com.apple.mail",
                    action: .gather
                )
        )
    }

    @Test("The picker pins Extend Sequence above, App… then Lua… below")
    func pickerSlots() {
        let slots = SequenceActionMenu.sequence([])
        #expect(slots == [.branch, .app, .lua])
        LocalizationManager.shared.select("en")
        #expect(SequenceActionMenu.branchLabel == "Extend Sequence")
        #expect(SequenceActionMenu.appLabel == "App…")
    }

    @Test("Each kind of key wears its container's face")
    func faces() throws {
        let menu = Self.flat(try Self.source("SequenceActionMenu.swift"))
        #expect(
            menu.contains(
                "ifnode.kind==.custom{Button(action:onEditLua){"
            )
        )
        #expect(menu.contains(".buttonStyle(SequenceDashedStyle())"))
        #expect(menu.contains("}else{Button{request=SequencePickRequest("))
        #expect(menu.contains(".settingsPopUpTrigger()"))
        // The rows the menu draws, not only its cursor's list.
        #expect(menu.contains("pinned(.branch,Self.branchLabel"))
        #expect(menu.contains("pinned(.app,Self.appLabel"))
        #expect(menu.contains("pinned(.lua,Self.luaLabel"))
        let row = Self.flat(try Self.source("SequenceNodeRow+Popovers.swift"))
        #expect(row.contains("SequenceContainerFace(face:.tinted){"))
        // The fold and the name are two buttons (amendment).
        #expect(
            row.contains(
                "disclosure(width:12).font(.caption.weight(.semibold))Button{"
                    + "editingBranch=SequenceBranchRequest(id:node.id)"
            )
        )
    }

    /// The popovers take the Lua rows' own pieces, never copies.
    @Test("The popovers share the Lua rows' views")
    func sharedViews() throws {
        let popovers = try Self.source("SequenceNodeRow+Popovers.swift")
        #expect(popovers.contains("ShortcutSymbolPicker.lua("))
        #expect(popovers.contains("ShortcutSymbolPicker.branch("))
        #expect(popovers.contains("ShortcutGroupField("))
        #expect(popovers.contains("LuaBindingEditor("))
        #expect(popovers.contains("model.shortcutGroupsInUse()"))
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.dir)
        for url in try SourceScan.swiftSources(under: root) {
            let text = try SourceScan.strippedSource(at: url)
            #expect(
                !text.contains("IconPicker("),
                "\(url.lastPathComponent) draws its own icon picker"
            )
        }
    }

    @Test("A renamed branch keeps its symbol")
    func renameKeepsSymbol() {
        var branch = KeyBinding.sequence(combo: "w", label: "Windows")
        branch.symbol = "macwindow"
        var rows = [
            KeyBinding.sequence(combo: "ctrl+alt+space", steps: [branch])
        ]
        let editing = SequenceEditing(
            bindings: .init(get: { rows }, set: { rows = $0 }),
            rootID: rows[0].id
        )
        editing.field(branch.id, \.label).wrappedValue = "Panes"
        let stored = SequenceTree.node(branch.id, in: rows[0])
        #expect(stored?.label == "Panes")
        #expect(stored?.symbol == "macwindow")
    }

    @Test("The hint panel leads a branch with its symbol, else folder")
    func hintBranchGlyph() throws {
        var named = KeyBinding.sequence(
            combo: "a",
            label: "Apps",
            steps: [KeyBinding(combo: "s", lua: "KiwiDesk.reload_config()")]
        )
        named.symbol = "app.badge"
        let plain = KeyBinding.sequence(
            combo: "w",
            label: "Windows",
            steps: [KeyBinding(combo: "h", lua: "KiwiDesk.reload_config()")]
        )
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                .sequence(combo: "ctrl+alt+space", steps: [plain, named])
            ]
        )
        let hint = try #require(
            KeySequenceHint.of(
                KeySequenceProgress(leader: "ctrl+alt+space", path: []),
                in: layer
            )
        )
        #expect(
            hint.branches.map(\.symbol) == [BranchMark.symbol, "app.badge"]
        )
        let row = KeySequenceHintView.branchRow(hint.branches[0])
        #expect(row.icon == "folder")
        #expect(row.accessoryIcon == "chevron.forward")
        #expect(
            ShortcutsReferenceBuilder.verbSymbols.contains(BranchMark.symbol)
        )
    }
}
