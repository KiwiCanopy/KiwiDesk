import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// The bordered action button lifts on the button-chip ladder
/// (#2377): rest, a grey step under the pointer, one more pressed,
/// and a disabled button reacting to neither.
@Suite("Button chip style (#2377)")
@MainActor
struct ButtonChipStyleTests {
    @Test("the fill ladder steps rest, hover, pressed")
    func ladder() {
        #expect(
            ButtonChipStyle.fill(pressed: false, hovered: false)
                == SettingsTheme.chipRest
        )
        #expect(
            ButtonChipStyle.fill(pressed: false, hovered: true)
                == SettingsTheme.chipHover
        )
        #expect(
            ButtonChipStyle.fill(pressed: true, hovered: true)
                == SettingsTheme.chipPressed
        )
    }

    /// A disabled button never reacts, so both inputs pass through
    /// `isEnabled` where the face reads them.
    @Test("a disabled button neither lifts nor presses")
    func disabledIsInert() throws {
        let face = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Settings/ButtonChipStyle.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(face.contains("pressed:isEnabled&&configuration.isPressed"))
        #expect(face.contains("hovered:isEnabled&&hovered"))
    }

    /// A caller's `.font` wins over the size default, as it did on
    /// the system bezel (`IconPicker`'s caption, the Lua editor's
    /// callout).
    @Test("a caller's font wins over the size default")
    func callerFontWins() throws {
        let face = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Settings/ButtonChipStyle.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(face.contains(".font(font??.system(size:metrics.font))"))
        #expect(face.components(separatedBy: ".font(").count == 2)
    }

    /// KiwiHub's footer buttons wear the same seal as Settings'.
    @Test("KiwiHub's chord buttons take the action-button seal")
    func kiwiHubTakesTheSeal() throws {
        let button = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Jump/KeyPanelChordButton.swift"
            )
        )
        #expect(button.contains(".settingsActionButton()"))
    }

    /// A segment's press keeps its hover tone: `.plain` faded it
    /// lighter than the hover.
    @Test("a segment's press does not fade")
    func segmentPressKeepsTone() throws {
        let picker = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Common/"
                    + "SegmentedPicker.swift"
            )
        )
        #expect(picker.contains(".buttonStyle(SegmentPressStyle())"))
        #expect(!picker.contains(".buttonStyle(.plain)"))
    }
}
