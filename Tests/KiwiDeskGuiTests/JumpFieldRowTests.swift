import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's field row rides the panel's edges (#3570 ▸ Amendment
/// 4): the search field at the leading inset, the side switch at the
/// trailing one, both placed by the window's frame alone — no
/// animation of their own — and the field built once, so ⇥ keeps its
/// focus and caret. The width is read from a hosted render; the rest
/// is wiring a headless test reads from the source.
@Suite("KiwiHub field row")
@MainActor
struct JumpFieldRowTests {
    private func source() throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelView.swift"
                )
        )
        .filter { !$0.isWhitespace }
    }

    private func body(_ after: String) throws -> String {
        let text = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Jump/JumpPanelView.swift"
                )
        )
        return try #require(
            SourceScan.declarationBody(after: after, in: text)
        ).filter { !$0.isWhitespace }
    }

    /// The row spans the panel at the rows' inset, never a fixed
    /// width in the middle of a wider panel.
    @Test("the row spans the panel at the content inset")
    func spansThePanel() throws {
        let field = try body("private var field: some View")
        #expect(field.contains(".padding(.horizontal,Self.fieldInset)"))
        #expect(field.contains(".frame(maxWidth:.infinity)"))
        #expect(!field.contains("frame(width:width"))
        #expect(
            JumpPanelView.fieldInset
                == JumpShortcutsView.kiwiHubInset
        )
    }

    /// The scope's cross-fade runs below the field: the row takes no
    /// animation of its own, so it moves only with the frame.
    @Test("the field row runs no animation of its own")
    func noOwnAnimation() throws {
        let side = try body("private var side: some View")
        let field = try #require(side.range(of: "VStack(spacing:0){field"))
        let rest = side[field.upperBound...]
        #expect(rest.hasPrefix("Group{"))
        #expect(rest.contains("}.animation(reduceMotion?nil:"))
        let root = try body("var body: some View")
        #expect(!root.contains(".animation("))
        let row = try body("private var field: some View")
        #expect(!row.contains(".animation("))
        #expect(!row.contains("withAnimation"))
    }

    /// ⇥ keeps the field's focus: it is built once, with no identity
    /// the side keys, and a scope change re-focuses only a field that
    /// lost the focus.
    @Test("⇥ keeps the field, its focus and caret")
    func tabKeepsTheField() throws {
        let field = try body("private var field: some View")
        #expect(!field.contains(".id("))
        #expect(
            field.contains(
                ".onChange(of:model.scope){if!fieldFocused{fieldFocused=true}}"
            )
        )
        #expect(
            !field.contains(".onChange(of:model.scope){fieldFocused=true}")
        )
        // The field reads the model's query by one binding, for every
        // side; nothing rebuilds it per side.
        #expect(try source().occurrences(of: "TextField(") == 1)
    }

    /// VoiceOver reads the search field, then the side switch.
    @Test("the field reads before the side switch")
    func readingOrder() throws {
        let field = try body("private var field: some View")
        let text = try #require(field.range(of: "TextField("))
        let tabs = try #require(
            field.range(of: "JumpScopeSwitch(model:model)")
        )
        #expect(text.lowerBound < tabs.lowerBound)
    }

    /// A wide side's rendered root reaches its edges, the field row
    /// with it.
    @Test("a wide side renders at its own width")
    func wideSideSpans() {
        LocalizationManager.shared.select("en")
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            sheetCap: 200
        )
        model.loadShortcuts = {
            ShortcutsReference(
                layerName: KeyLayer.defaultName,
                controls: (1...4).map { group in
                    ShortcutSubgroup(
                        title: "Group \(group)",
                        rows: (1...8).map {
                            ShortcutRow(
                                id: "\(group).\($0)",
                                label: "Row \($0)",
                                combo: "⌃⌥X"
                            )
                        }
                    )
                },
                inactive: [],
                desktopAway: [],
                apps: [],
                custom: []
            )
        }
        model.setScope(.shortcuts)
        let host = NSHostingView(
            rootView: LocaleScopedRoot {
                JumpPanelView(
                    model: model,
                    presence: PanelPresence(reduceMotion: true),
                    width: JumpPanelView.width
                )
            }
            .environmentObject(LocalizationManager.shared)
        )
        #expect(model.sideWidth > JumpPanelView.width)
        #expect(host.fittingSize.width == model.sideWidth)
    }
}
