import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// About's license sheet (#3286): the text read-only, selectable
/// and monospaced, ⌘F on the find bar, and its one dismissal ending
/// that sheet alone, never About under it.
@Suite("License sheet (#3286)")
@MainActor
struct LicenseSheetTests {
    @Test("the text view is read-only, selectable and monospaced")
    func textViewShape() throws {
        let scroll = LicenseTextFinding.scrollableTextView()
        let view = try #require(scroll.documentView as? NSTextView)
        #expect(!view.isEditable)
        #expect(view.isSelectable)
        #expect(view.usesFindBar)
        #expect(view.font?.pointSize == 11)
        #expect(
            view.font?.fontDescriptor.symbolicTraits
                .contains(.monoSpace) == true
        )
        #expect(view.isVerticallyResizable)
        #expect(view.textContainer?.widthTracksTextView == true)
    }

    @Test("⌘F, ⌘G and ⇧⌘G reach the find bar; nothing else does")
    func findChords() {
        #expect(
            LicenseTextFinding.action(key: "f", modifiers: [.command])
                == .showFindInterface
        )
        #expect(
            LicenseTextFinding.action(key: "g", modifiers: [.command])
                == .nextMatch
        )
        #expect(
            LicenseTextFinding.action(
                key: "G",
                modifiers: [.command, .shift]
            ) == .previousMatch
        )
        #expect(
            LicenseTextFinding.action(
                key: "f",
                modifiers: [.command, .capsLock]
            ) == .showFindInterface
        )
        #expect(
            LicenseTextFinding.action(key: "f", modifiers: []) == nil
        )
        #expect(
            LicenseTextFinding.action(key: "c", modifiers: [.command])
                == nil
        )
    }

    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings/Home")
            .appendingPathComponent(path)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    @Test("the sheet builds its view, and dismisses itself alone")
    func wiring() throws {
        let sheet = try squashed("LicenseSheet.swift")
        #expect(
            sheet.contains(
                "letscroll=LicenseTextFinding.scrollableTextView()"
            )
        )
        let about = try squashed("AboutSheet.swift")
        #expect(
            about.contains(
                ".sheet(item:$licenseRequest){requestin"
                    + "LicenseSheet(request:request){licenseRequest=nil}}"
            )
        )
        // The text only opens in a sheet when the bundle carries
        // it; otherwise the row is the plain GitHub link.
        #expect(
            about.contains(
                "case.bundled(letfile):Button{licenseRequest="
                    + "LicenseDocuments.text(at:file).map{"
                    + "LicenseRequest(title:title,text:$0)}}"
            )
        )
        #expect(about.contains("case.link(leturl):link(title,url)"))
    }
}
