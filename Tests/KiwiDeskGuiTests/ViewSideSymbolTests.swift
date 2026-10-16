import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Each View line's heading and the footer button that opens its
/// Settings page wear that page's own symbol — the mark its card
/// in Settings wears — so the symbol is the page the button
/// actually lands on, and decorative to VoiceOver.
@Suite("KiwiHub View side symbols")
@MainActor
struct ViewSideSymbolTests {
    @Test("a line's symbol is the page its ⌘, lands on")
    func symbolIsTheLanding() {
        for line in ViewPickList.Line.allCases {
            let landing = JumpPanelController.landing(
                line,
                nil,
                live: .bsp
            )
            #expect(
                SettingsAnchor(landing: landing).destination
                    == ViewPickText.destination(line),
                "\(line)"
            )
        }
    }

    private func source(_ name: String) throws -> String {
        let text = try String(
            contentsOf: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/Jump")
                .appendingPathComponent(name),
            encoding: .utf8
        )
        let stripped = SourceScan.stripComments(text)
        #expect(!stripped.isEmpty, "\(name) read empty")
        return stripped
    }

    @Test("the heading and the button draw the line's symbol")
    func headingAndButtonWearIt() throws {
        let side = try source("JumpViewSide.swift")
        let heading = try #require(
            SourceScan.declarationBody(
                after: "private func heading",
                in: side
            )
        )
        #expect(
            heading.contains(
                "Image(systemName: ViewPickText.destination(line).symbol)"
            )
        )
        let footer = try source("JumpPanelView+Footer.swift")
        #expect(
            footer.occurrences(
                of: "symbol: ViewPickText.destination(line).symbol"
            ) == 1
        )
        let button = try source("KeyPanelChordButton.swift")
        #expect(button.contains("Image(systemName: symbol)"))
    }

    /// Decorative: VoiceOver names the heading and the button by
    /// their titles alone.
    @Test("the symbols are hidden from VoiceOver")
    func symbolsAreSilent() throws {
        for (name, needle) in [
            (
                "JumpViewSide.swift",
                "Image(systemName: ViewPickText.destination(line).symbol)"
            ),
            ("KeyPanelChordButton.swift", "Image(systemName: symbol)"),
        ] {
            let text = try source(name)
            let site = try #require(text.range(of: needle))
            let chain = text[site.upperBound...].prefix(160)
            #expect(chain.contains(".accessibilityHidden(true)"), "\(name)")
        }
    }
}
