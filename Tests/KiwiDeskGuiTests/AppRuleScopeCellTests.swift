import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Space row's scope cell (#3415): a titled row's scope item names
/// the bare row it would make, and the cell keeps one width, its
/// title cut in the middle, so an app's Space and "Applies to"
/// columns line up. Nothing headless can open a `Menu`, so the
/// wiring is held on the source, scoped to a brace-balanced body.
@Suite("App Rules scope cell (#3415)", .serialized)
@MainActor
struct AppRuleScopeCellTests {
    private let file = "AppRuleSpaceRow+Scope.swift"

    private static func squashed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private func raw() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/" + file
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // An empty read fails-open the negative clauses below.
        #expect(text.count > 400, "\(file) read empty")
        return text
    }

    /// The brace-balanced body after `signature`.
    private func body(of signature: String) throws -> String {
        let text = try raw()
        let offset = try #require(
            text.range(of: signature),
            "\(signature) is gone from \(file)"
        )
        var cursor = text.distance(
            from: text.startIndex,
            to: offset.upperBound
        )
        let found = try #require(
            SourceScan.balanced(
                Array(text),
                from: &cursor,
                open: "{",
                close: "}"
            ),
            "\(signature) has no balanced body to read"
        )
        return Self.squashed(found)
    }

    @Test("the bare words follow whether other rows remain")
    func bareWords() {
        LocalizationManager.shared.select("en")
        #expect(AppRuleScopeWords.bare(besideOthers: false) == "All windows")
        #expect(
            AppRuleScopeWords.bare(besideOthers: true) == "All other windows"
        )
    }

    @Test("a titled row's scope item names the row it would become")
    func titledItemNamesItsRow() throws {
        let menu = try body(of: "private var scopeMenu: some View")
        #expect(menu.contains("Button(becomesLabel)"))
        #expect(!menu.contains("Button(AppRuleScopeWords.all)"))
        #expect(menu.contains(".disabled(hasBare)"))
        let becomes = try body(of: "var becomesLabel: String")
        #expect(
            becomes.contains(
                "besideOthers:hasBare||siblings.contains{$0!=row.fragment}"
            )
        )
        let label = try body(of: "var scopeLabel: String")
        #expect(
            label.contains("AppRuleScopeWords.bare(besideOthers:!siblings")
        )
    }

    @Test("the cell keeps one width and draws a fitted title")
    func cellKeepsItsWidth() throws {
        let menu = try body(of: "private var scopeMenu: some View")
        #expect(menu.contains("text:AppRuleScopeFit.middle(scopeLabel)"))
        let file = Self.squashed(try raw())
        let column = "width:SettingsMetrics.appRuleScopeColumn"
        #expect(file.components(separatedBy: column).count == 2)
    }

    @Test("a title that fits is left whole")
    func fitsWhole() {
        let font = NSFont.systemFont(ofSize: 12)
        #expect(
            AppRuleScopeFit.middle("All windows", width: 160, font: font)
                == "All windows"
        )
    }

    @Test("a long title keeps its head and tail inside the width")
    func longTitleIsCutInTheMiddle() {
        let font = NSFont.systemFont(ofSize: 12)
        let text = "Windows titled “Quarterly report draft — final v7”"
        let fitted = AppRuleScopeFit.middle(text, width: 160, font: font)
        let width = (fitted as NSString)
            .size(withAttributes: [.font: font]).width
        #expect(width <= 160, "“\(fitted)” is \(width) pt")
        #expect(fitted.contains("…"))
        #expect(fitted.hasPrefix("Windows"))
        #expect(fitted.hasSuffix("v7”"))
        // The longest cut: one more character would not fit.
        #expect(fitted.count >= 20, "“\(fitted)” cut too short")
    }
}
