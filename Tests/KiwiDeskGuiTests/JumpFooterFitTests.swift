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
        typealias Row = JumpFooterRow<EmptyView, EmptyView>
        return JumpFooterMidline.room(
            JumpPanelView.width - 2 * Row.inset,
            leading: leading,
            trailing: trailing,
            spacing: Row.spacing
        )
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
                    button(LayoutPickText.keep, "⌘S")
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

    /// The cue stands whole in the leading slot, and leaves the
    /// centred hints their first one, in every language.
    @Test("the Shortcuts side keeps its scroll cue in every language")
    func shortcutsKeepItsCue() throws {
        defer { LocalizationManager.shared.select("en") }
        typealias Row = JumpFooterRow<EmptyView, EmptyView>
        let rowWidth = JumpPanelView.width - 2 * Row.inset
        for code in try Self.locales() {
            LocalizationManager.shared.select(code)
            let text = try #require(JumpFooter.scrollHint(for: .shortcuts))
            let cue = width(JumpScrollCue(text: text).font(.caption))
            #expect(cue > 0, "\(code)")
            #expect(
                cue <= rowWidth * JumpFooterMidline.controlShare,
                "\(code): cue \(cue) pt passes the slot"
            )
            let capped = width(JumpLayerLabel(name: Self.layer), cap: 280)
            #expect(capped <= 280, "\(code): the layer chip passes its cap")
            let footer = JumpFooter(scope: .shortcuts, overflows: true)
            let room = room(
                leading: cue,
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
            let first = width(footer.row(Array(footer.hints.prefix(1))))
            #expect(first <= room, "\(code): \(first) pt in \(room) pt")
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
        #expect(
            footer.contains("JumpFooterMidline(spacing: Self.spacing)")
        )
        // The middle is placed at the centre the clamp decides.
        let midline = SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(
                    "JumpFooterMidline.swift"
                ),
                encoding: .utf8
            )
        )
        let place = try #require(
            SourceScan.declarationBody(
                after: "func placeSubviews",
                in: midline
            )
        )
        #expect(place.contains("Self.centre("))
        #expect(place.contains("x: bounds.minX + centre"))
    }

    /// `shortcutsChrome` states what the Shortcuts side draws
    /// besides its sheet, derived from the footer row's height; the
    /// field, two dividers and the drawn row must match it, or the
    /// sheet's cap is measured against a fiction.
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
        #expect(
            abs(drawn - allowed) < 1,
            "draws \(drawn) pt, allows \(allowed)"
        )
    }

    /// The hints share one centre on every side while they fit, and
    /// move toward the narrower control only as far as they must.
    @Test("the hints sit on the midline, and leave it only to fit")
    func hintsSitOnTheMidline() {
        typealias M = JumpFooterMidline
        // Room on both sides: the midline, whatever the controls.
        #expect(
            M.centre(600, leading: 0, trailing: 150, middle: 200, spacing: 12)
                == 300
        )
        #expect(
            M.centre(
                600,
                leading: 100,
                trailing: 150,
                middle: 200,
                spacing: 12
            )
                == 300
        )
        // Too wide to centre beside the trailing control: it moves
        // left until it clears it, and no further.
        let tight = M.centre(
            600,
            leading: 0,
            trailing: 150,
            middle: 400,
            spacing: 12
        )
        #expect(abs(tight - CGFloat(600 - 150 - 12 - 200)) < 0.5)
        #expect(
            JumpFooterMidline.room(
                600,
                leading: 0,
                trailing: 150,
                spacing: 12
            ) == 438
        )
    }
}
