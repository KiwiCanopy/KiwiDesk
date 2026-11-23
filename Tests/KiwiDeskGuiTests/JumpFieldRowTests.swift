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

    /// The field row runs no animation of its own: it moves only
    /// with the window's frame. The side's cross-fade is keyed on the
    /// scope alone, which never moves the frame in its transaction.
    @Test("the field row runs no animation of its own")
    func noOwnAnimation() throws {
        let row = try body("private var field: some View")
        #expect(!row.contains(".animation("))
        #expect(!row.contains("withAnimation"))
        let root = try body("var body: some View")
        #expect(root.occurrences(of: ".animation(") == 1)
        #expect(root.contains("value:model.scope)"))
    }

    /// A side taller than the window, before the refit grows it,
    /// overflows downward: without the 0 floor the host centres it
    /// and the field row rides up past the top (owner's recording,
    /// 2026-11-23).
    @Test("a taller side overflows down, never up")
    func overflowsDown() throws {
        LocalizationManager.shared.select("en")
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 9,
            sheetCap: 200
        )
        let host = Self.host(model)
        let tall = host.fittingSize.height
        // Half the side's height: the window before a refit.
        host.frame = CGRect(
            x: 0,
            y: 0,
            width: JumpPanelView.width,
            height: tall / 2
        )
        host.layoutSubtreeIfNeeded()
        let field = try #require(Self.textField(in: host))
        let frame = field.convert(field.bounds, to: host)
        // The field sits at the top, inside the window.
        #expect(frame.minY >= 0)
        #expect(frame.maxY <= JumpPanelView.fieldHeight + 4)
    }

    private static func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        for child in view.subviews {
            if let found = textField(in: child) { return found }
        }
        return nil
    }

    /// ⇥ keeps the field's focus: it is built once, with no identity
    /// the side keys, and a scope change hands the focus back to a
    /// field that lost it to a click on the switch.
    @Test("⇥ keeps the field, its focus and caret")
    func tabKeepsTheField() throws {
        let field = try body("private var field: some View")
        #expect(!field.contains(".id("))
        #expect(
            field.contains(".onChange(of:model.scope){fieldFocused=true}")
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
        let model = Self.wideModel()
        let host = Self.host(model)
        #expect(model.sideWidth > JumpPanelView.width)
        #expect(host.fittingSize.width == model.sideWidth)
    }

    /// Before the window glides open, a wide side lays out in the
    /// narrow window: the field row spans the window as it is, so the
    /// switch moves with the window's edge, never ahead of it
    /// (owner, 2026-11-23).
    @Test("the row spans the window, not the side ahead of the glide")
    func rowWaitsForTheGlide() throws {
        LocalizationManager.shared.select("en")
        let model = Self.wideModel()
        let host = Self.host(model)
        host.frame = CGRect(
            x: 0,
            y: 0,
            width: JumpPanelView.width,
            height: host.fittingSize.height
        )
        host.layoutSubtreeIfNeeded()
        let field = try #require(Self.textField(in: host))
        let frame = field.convert(field.bounds, to: host)
        #expect(model.sideWidth > JumpPanelView.width)
        #expect(frame.minX >= 0)
        #expect(frame.maxX < JumpPanelView.width)
    }

    private static func wideModel() -> JumpModel {
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
        return model
    }

    private static func host(_ model: JumpModel) -> NSView {
        NSHostingView(
            rootView: LocaleScopedRoot {
                JumpPanelView(
                    model: model,
                    presence: PanelPresence(reduceMotion: true),
                    width: JumpPanelView.width
                )
            }
            .environmentObject(LocalizationManager.shared)
        )
    }
}
