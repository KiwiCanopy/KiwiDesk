import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's footer row carries a side's controls beside its key
/// hints, so in every shipped language the controls leave room
/// for what must stay — View's first hint, Shortcuts' scroll cue —
/// and the rest shed from the end. Measured on each side's widest
/// case as AppKit sizes the real views: one hosting measurement
/// per piece per locale on the main actor.
@Suite("KiwiHub footer fit")
@MainActor
struct JumpFooterFitTests {
    private static let profile = "Super Ultrawide"
    private static let layer = String(repeating: "Hyper layer ", count: 8)

    private static func locales() throws -> [String] {
        let directory = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let names = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        let codes = names.filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
        #expect(codes.count > 1, "no catalogs found")
        return codes
    }

    private func size(
        _ view: some View,
        width: CGFloat = 4000
    ) -> CGSize {
        NSHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: width, height: 400))
    }

    private func width(_ view: some View, cap: CGFloat = 4000) -> CGFloat {
        size(
            view.fixedSize(horizontal: cap == 4000, vertical: true),
            width: cap
        ).width
    }

    /// What the row leaves its hints beside `leading` and
    /// `trailing`, read off the row's own spacing and inset.
    private func room(leading: CGFloat, trailing: CGFloat) -> CGFloat {
        JumpPanelView.width - 2 * JumpFooterRow<EmptyView, EmptyView>.inset
            - 2 * JumpFooterRow<EmptyView, EmptyView>.spacing
            - leading - trailing
    }

    private func button(
        _ title: String,
        _ chord: String,
        symbol: String? = nil
    ) -> some View {
        KeyPanelChordButton(title: title, chord: chord, symbol: symbol) {}
    }

    @Test("the View side keeps its first hint in every language")
    func viewKeepsItsFirstHint() throws {
        defer { LocalizationManager.shared.select("en") }
        for code in try Self.locales() {
            LocalizationManager.shared.select(code)
            let footer = JumpFooter(scope: .view, overflows: false)
            // The Settings button reserves its widest label.
            let leading = width(
                KeyPanelChordButton(
                    title: ViewPickText.settings(.profile),
                    chord: "⌘,",
                    reserves: ViewPickText.settingsLabels
                ) {}
            )
            let room = room(
                leading: leading,
                trailing: width(
                    button(LayoutPickText.keep(Self.profile), "⌘S")
                )
            )
            let hints = footer.hints
            let kept =
                (0...hints.count).last {
                    width(footer.row(Array(hints.prefix($0)))) <= room
                } ?? 0
            print("footer fit view \(code): \(kept)/\(hints.count)")
            #expect(kept >= 1, "\(code) leaves the hints \(room) pt")
        }
    }

    /// A layer named as layers are keeps the whole cue; a name at
    /// the chip's cap truncates in the chip, and the cue after it
    /// (`shapeIsWired`'s truncating fallback).
    @Test("the Shortcuts side keeps its scroll cue in every language")
    func shortcutsKeepItsCue() throws {
        defer { LocalizationManager.shared.select("en") }
        for code in try Self.locales() {
            LocalizationManager.shared.select(code)
            let footer = JumpFooter(scope: .shortcuts, overflows: true)
            let capped = width(JumpLayerLabel(name: Self.layer), cap: 280)
            #expect(capped <= 280, "\(code): the layer chip passes its cap")
            let room = room(
                leading: width(JumpLayerLabel(name: "Navigation")),
                trailing: width(
                    button(
                        L(
                            "shortcuts.panel.edit_in_settings",
                            "Edit in Settings…"
                        ),
                        "⌘,"
                    )
                )
            )
            let cue = width(footer.row([]))
            // The row drawn is the cue itself, not an empty one.
            let text = try #require(footer.scrollHint)
            #expect(cue >= width(Text(text).font(.caption)), "\(code)")
            #expect(cue <= room, "\(code): cue \(cue) pt in \(room) pt")
        }
    }

    /// The shedding and the controls' priority are what the fit
    /// rests on, so both are pinned at their one site.
    @Test("the hints shed and the controls are sized first")
    func shapeIsWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Jump")
        let chrome = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "JumpPanelChrome.swift"
                ),
                encoding: .utf8
            )
        )
        let footer = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "JumpPanelView+Footer.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(chrome.contains("ViewThatFits(in: .horizontal)"))
        #expect(chrome.contains("(0...hints.count).reversed()"))
        // The last candidate, which ViewThatFits takes when none
        // fits, truncates instead of spilling.
        let chars = Array(chrome)
        let opener = try #require(
            chrome.range(of: "ViewThatFits(in: .horizontal)")
        )
        var cursor = chrome.distance(
            from: chrome.startIndex,
            to: opener.upperBound
        )
        let closure = try #require(
            SourceScan.balanced(chars, from: &cursor, open: "{", close: "}")
        )
        #expect(closure.contains("row([], fixed: false)"))
        #expect(footer.contains("leading.layoutPriority(1)"))
        #expect(footer.contains("trailing.layoutPriority(1)"))
    }

    /// `shortcutsChrome` states what the Shortcuts side draws
    /// besides its sheet; the field, two dividers and the footer
    /// row with its button must fit inside it, with little to
    /// spare, or the sheet's cap is measured against a fiction.
    @Test("the Shortcuts chrome allowance matches what is drawn")
    func chromeMatchesTheDrawing() {
        LocalizationManager.shared.select("en")
        let row = JumpFooterRow(
            footer: JumpFooter(scope: .shortcuts, overflows: true),
            leading: { JumpLayerLabel(name: "Hyper") },
            trailing: { button("Edit in Settings…", "⌘,") }
        )
        let drawn =
            JumpPanelView.fieldHeight + 2
            + size(row, width: JumpPanelView.width).height
        let allowed = JumpPanelController.shortcutsChrome
        #expect(drawn <= allowed, "draws \(drawn) pt over \(allowed)")
        #expect(drawn > allowed - 16, "draws \(drawn) pt of \(allowed)")
    }
}
