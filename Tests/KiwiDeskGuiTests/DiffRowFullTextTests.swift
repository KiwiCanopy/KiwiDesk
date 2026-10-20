import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A save-pill row never hides what changed: its label wraps rather
/// than truncating, and its hover text states the row in full
/// (owner eyeball, 2026-10-20).
@MainActor
@Suite("A diff row says what changed in full")
struct DiffRowFullTextTests {
    private func row() -> SettingsDiffRow {
        SettingsDiffRow(
            id: "row",
            key: .kiwiVision(.lenses),
            label: "Show or hide the App Bar",
            oldValue: "⌃⌥H",
            newValue: nil,
            reach: "Profiles: 8"
        )
    }

    @Test func hoverTextIsWhole() {
        LocalizationManager.shared.select("en")
        #expect(
            SettingsDiffRowsView.fullText(row())
                == "Show or hide the App Bar · Profiles: 8 · ⌃⌥H → —"
        )
    }

    @Test func noteReplacesTheValues() {
        var noted = row()
        noted.changeNote = "New profiles get this shortcut"
        #expect(
            SettingsDiffRowsView.fullText(noted).hasSuffix(
                "· New profiles get this shortcut"
            )
        )
    }

    /// The label and reach wrap, and the row carries the hover text.
    @Test func rowButtonNeitherTruncatesNorHides() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/SettingsDiffRowsView.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        let start = try #require(source.range(of: "func rowButton("))
        let tail = source[start.upperBound...]
        let end = try #require(tail.range(of: "\n    }\n")).lowerBound
        let body = tail[..<end]
        let label = try #require(body.range(of: "Text(row.label)"))
        let afterLabel = body[label.upperBound...]
        let valueCall = try #require(afterLabel.range(of: "valueReadout"))
        let labelRun = afterLabel[..<valueCall.lowerBound]
        #expect(!labelRun.contains(".lineLimit("))
        #expect(body.contains(".help(Self.fullText(row))"))
    }
}
