import Foundation
import Testing

@testable import KiwiDesk

/// Every control on the update window's glass sits on the opaque
/// control ground (#3666): the glass adapts to the backdrop, so a
/// fixed ink on a translucent face or an adaptive native bezel
/// sinks where the glass greys — light over a dark backdrop, dark
/// over a bright one. The glass cannot be rendered offscreen, so
/// the guard is a scan of the Updates files; the ground is `card`,
/// on which `SettingsThemeContrastTests` measures every face's ink.
/// Off the main actor: one read of the Updates folder.
@Suite("Update window controls on the opaque ground (#3666)")
struct UpdateControlGroundTests {
    private static var updates: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Updates")
    }

    private static func squashed(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: updates.appendingPathComponent(name)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    private static func sources() throws -> [(String, String)] {
        let files = try SourceScan.swiftSources(under: updates)
        #expect(files.count >= 20, "scanned \(files.count) files")
        return try files.map { file in
            (
                file.lastPathComponent,
                try squashed(file.lastPathComponent)
            )
        }
    }

    @Test("no native pop-up bezel on the glass")
    func noNativePopUp() throws {
        for (name, text) in try Self.sources() {
            #expect(
                !text.contains(".pickerStyle(.menu)")
                    && !text.contains("MenuPickerStyle()"),
                "\(name) draws a native pop-up, whose bezel adapts"
            )
        }
    }

    @Test("every action button stands on the ground")
    func actionButtonsStandOnTheGround() throws {
        var buttons = 0
        for (name, text) in try Self.sources() {
            let all = text.occurrences(of: ".settingsActionButton()")
            buttons += all
            #expect(
                text.occurrences(
                    of: ".settingsActionButton().updateActionGround()"
                ) == all,
                "\(name) has an action button off the ground"
            )
        }
        #expect(buttons >= 3, "found \(buttons) action buttons")
    }

    /// The pop-up seal is spelled once, in `UpdatePopUp`, on the
    /// ground; every pop-up in the window is that one.
    @Test("the pop-up's capsule stands on the ground")
    func popUpStandsOnTheGround() throws {
        for (name, text) in try Self.sources()
        where name != "UpdateControlGround.swift" {
            #expect(
                !text.contains(".settingsPopUpTrigger()"),
                "\(name) spells a pop-up trigger of its own"
            )
        }
        let source = try SourceScan.strippedSource(
            at: Self.updates.appendingPathComponent(
                "UpdateControlGround.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "struct UpdatePopUp",
                in: source
            ),
            "UpdatePopUp is gone"
        )
        let flat = body.split(whereSeparator: \.isWhitespace).joined()
        #expect(flat.contains(".settingsPopUpTrigger()"))
        #expect(flat.contains(".updateControlGround(Capsule())"))
        #expect(flat.contains(".pickerStyle(.inline)"))
    }

    @Test(
        "each selector draws the pop-up",
        arguments: [
            "WhatsNewReleasePicker.swift", "UpdateNotesTabStrip.swift",
        ]
    )
    func selectorsDrawThePopUp(file: String) throws {
        #expect(try Self.squashed(file).contains("UpdatePopUp("))
    }

    /// The shown strip, not the hidden one sizing it.
    @Test("the tab strip's segments stand on the ground")
    func segmentsStandOnTheGround() throws {
        let source = try SourceScan.strippedSource(
            at: Self.updates.appendingPathComponent(
                "UpdateNotesTabStrip.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(after: "var body", in: source),
            "the strip's body is gone"
        )
        let flat = body.split(whereSeparator: \.isWhitespace).joined()
        #expect(
            flat.contains(
                "SegmentedPicker(selection:$selection,options:options)"
                    + ".fixedSize().updateControlGround(Capsule())"
            )
        )
    }

    /// `card` is the ground the contrast suite measures the faces
    /// on; another fill would be a ground nobody measures.
    @Test("the ground is card")
    func groundIsCard() throws {
        let source = try SourceScan.strippedSource(
            at: Self.updates.appendingPathComponent(
                "UpdateControlGround.swift"
            )
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "func updateControlGround",
                in: source
            ),
            "updateControlGround is gone"
        )
        let flat = body.split(whereSeparator: \.isWhitespace).joined()
        #expect(flat.contains("shape.fill(SettingsTheme.card)"))
    }
}
