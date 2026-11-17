import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A Space row's scope cell (#3415): a titled row's scope item names
/// the bare row it would make, and the cell keeps one width, its
/// title cut in the middle, so an app's Space and "Applies to"
/// columns line up. Nothing headless can open a `Menu`, so the
/// wiring is held on the source, scoped to a brace-balanced body;
/// the width is held by rendering the menu. Main-actor spend: one
/// file read, a few string measurements and three hosted menus.
@Suite("App Rules scope cell (#3415)", .serialized)
@MainActor
struct AppRuleScopeCellTests {
    private let file = "AppRuleSpaceRow+Scope.swift"
    private let app = "com.brave.browser"

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

    private func row(_ fragment: String?) -> SpaceRuleRow {
        SpaceRuleRow(app: app, fragment: fragment)
    }

    /// The app's rules: a bare one when `bare`, a titled one each.
    private func config(bare: Bool, titled: [String]) -> GuiConfig {
        var config = GuiConfig()
        if bare { config.appRules[app] = "1" }
        for fragment in titled {
            config.titledAppRules[row(fragment).key] = "1"
        }
        return config
    }

    @Test("a row has others beside it only when its app does")
    func othersBeside() {
        let cases: [(GuiConfig, String?, Bool)] = [
            (config(bare: true, titled: []), nil, false),
            (config(bare: true, titled: ["Work"]), nil, true),
            (config(bare: false, titled: ["Work"]), "Work", false),
            (config(bare: false, titled: ["Work", "Job"]), "Work", true),
            (config(bare: true, titled: ["Work"]), "Work", true),
        ]
        for (config, fragment, others) in cases {
            #expect(
                SpaceRuleRows.othersBeside(row(fragment), in: config)
                    == others,
                "\(fragment ?? "bare") in \(config.titledAppRules)"
            )
        }
    }

    @Test("the bare words follow whether other rows remain")
    func bareWords() {
        LocalizationManager.shared.select("en")
        #expect(AppRuleScopeWords.bare(besideOthers: false) == "All windows")
        #expect(
            AppRuleScopeWords.bare(besideOthers: true) == "All other windows"
        )
    }

    @Test("both scope words read the one row-set answer")
    func labelsReadTheRowSet() throws {
        let menu = try body(of: "private var scopeMenu: some View")
        #expect(menu.contains("Button(becomesLabel)"))
        #expect(!menu.contains("Button(AppRuleScopeWords.all)"))
        for label in ["var becomesLabel: String", "var scopeLabel: String"] {
            #expect(
                try body(of: label).contains(
                    "AppRuleScopeWords.bare(besideOthers:othersBeside)"
                ),
                "\(label) decides its words by its own reading"
            )
        }
        #expect(
            try body(of: "private var othersBeside: Bool")
                .contains("SpaceRuleRows.othersBeside(row,")
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

    /// The scope cell's menu, styled as `scopeMenu` draws it.
    private func renderedWidth(_ text: String) -> CGFloat {
        let menu = Menu {
            Button("x") {}
        } label: {
            AppRuleMenuLabel(text: text, chevron: false)
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .fixedSize()
        .font(.callout)
        return NSHostingView(rootView: menu).fittingSize.width
    }

    /// AppKit draws the title in `AppRuleScopeFit.font`, whatever
    /// the row's SwiftUI font: two titles' rendered difference is
    /// their difference measured in it.
    @Test("the title is measured in the font AppKit draws it in")
    func measuresTheDrawnFont() {
        let short = "All windows"
        let long = String(repeating: "All other windows ", count: 3)
        let drawn = renderedWidth(long) - renderedWidth(short)
        let font = AppRuleScopeFit.font
        func measure(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        let measured = measure(long) - measure(short)
        #expect(
            abs(drawn - measured) <= 2,
            "drawn \(drawn), measured \(measured)"
        )
    }

    @Test("a fitted title and the widest bare scope fit the column")
    func renderedMenuFitsTheColumn() {
        let long = "Windows titled “Quarterly report draft, final v7 copy”"
        let fitted = AppRuleScopeFit.middle(long)
        #expect(fitted != long)
        #expect(
            renderedWidth(fitted) <= SettingsMetrics.appRuleScopeColumn,
            "“\(fitted)” renders past the column"
        )
        let whole = renderedWidth(
            String(repeating: "W", count: 200)
        )
        #expect(whole > SettingsMetrics.appRuleScopeColumn)
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
    }
}
