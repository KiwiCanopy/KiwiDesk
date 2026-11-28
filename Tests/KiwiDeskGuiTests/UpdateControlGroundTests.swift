import Foundation
import Testing

@testable import KiwiDesk

/// Every control on the update window's glass sits on the opaque
/// control ground (#3666): the glass adapts to the backdrop, so a
/// fixed ink on a translucent face or an adaptive native bezel
/// sinks where the glass greys — light over a dark backdrop, dark
/// over a bright one. The glass cannot be rendered offscreen, so
/// the guard is a scan; the ground is `card`, on which
/// `SettingsThemeContrastTests` measures every face's ink.
///
/// The subject is the glass, not a folder: the Updates files and
/// any other file that draws `updateWindowGround()` or
/// `updateFooterBar()` (the Standard notice). Three control kinds
/// are held — a pop-up, an action button, the tab strip's
/// segments; a further kind on this glass extends this suite.
/// Off the main actor: one read of the source tree.
@Suite("Update window controls on the opaque ground (#3666)")
struct UpdateControlGroundTests {
    private static var root: URL {
        SourceScan.repoRoot(from: #filePath)
    }

    private static var updates: URL {
        root.appendingPathComponent("Sources/KiwiDesk/Updates")
    }

    private static func flat(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined()
    }

    private static func source(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: updates.appendingPathComponent(name)
        )
    }

    /// Every file on the glass, comment-stripped.
    private static func glassSources() throws -> [(String, String)] {
        let tree = root.appendingPathComponent("Sources/KiwiDesk")
        let inUpdates = updates.standardizedFileURL.path + "/"
        var found: [(String, String)] = []
        for file in try SourceScan.swiftSources(under: tree) {
            let text = try SourceScan.strippedSource(at: file)
            let onGlass =
                file.standardizedFileURL.path.hasPrefix(inUpdates)
                || text.contains(".updateWindowGround()")
                || text.contains(".updateFooterBar()")
            if onGlass { found.append((file.lastPathComponent, text)) }
        }
        #expect(found.count >= 25, "scanned \(found.count) files")
        #expect(
            found.contains { $0.0 == "StandardFallbackView.swift" },
            "the scan no longer reaches the Standard notice"
        )
        return found
    }

    /// `name` called as a type at an identifier boundary, so
    /// `SegmentedPicker(` and `UpdatePopUp(` do not count as
    /// `Picker(`. Trades: a type spelled through a typealias, or
    /// `SwiftUI.Picker`, which no file here writes.
    private static func calls(_ name: String, in text: String) -> Int {
        let chars = Array(text)
        let needle = Array(name)
        var count = 0
        var index = 0
        while index + needle.count <= chars.count {
            defer { index += 1 }
            guard Array(chars[index..<index + needle.count]) == needle
            else { continue }
            if index > 0 {
                let before = chars[index - 1]
                if before.isLetter || before.isNumber || before == "_"
                    || before == "."
                {
                    continue
                }
            }
            var after = index + needle.count
            while after < chars.count, chars[after].isWhitespace {
                after += 1
            }
            if after < chars.count, "({".contains(chars[after]) {
                count += 1
            }
        }
        return count
    }

    /// A native `Picker` (styleless is the pop-up on macOS) or a
    /// `Menu` draws an adaptive bezel; only `UpdatePopUp`'s own
    /// body may hold one, behind its capsule.
    @Test("no native pop-up or menu on the glass")
    func noNativePopUp() throws {
        for (name, text) in try Self.glassSources() {
            var rest = text
            if name == "UpdatePopUp.swift" {
                let body = try #require(
                    SourceScan.declarationBody(
                        after: "struct UpdatePopUp",
                        in: text
                    ),
                    "UpdatePopUp is gone"
                )
                rest = text.replacingOccurrences(of: body, with: "")
            }
            #expect(
                Self.calls("Picker", in: rest) == 0
                    && Self.calls("Menu", in: rest) == 0,
                "\(name) draws a native pop-up, whose bezel adapts"
            )
        }
    }

    @Test("every action button stands on the ground")
    func actionButtonsStandOnTheGround() throws {
        var buttons = 0
        for (name, text) in try Self.glassSources() {
            let flat = Self.flat(text)
            let all = flat.occurrences(of: ".settingsActionButton()")
            buttons += all
            #expect(
                flat.occurrences(
                    of: ".settingsActionButton().updateActionGround()"
                ) == all,
                "\(name) has an action button off the ground"
            )
        }
        #expect(buttons >= 4, "found \(buttons) action buttons")
    }

    /// The pop-up seal is spelled once on this glass, in
    /// `UpdatePopUp`, the capsule's ground on the Menu's own chain
    /// and the inline style on the Picker inside it.
    @Test("the pop-up's capsule stands on the ground")
    func popUpStandsOnTheGround() throws {
        for (name, text) in try Self.glassSources()
        where name != "UpdatePopUp.swift" {
            #expect(
                !text.contains(".settingsPopUpTrigger()"),
                "\(name) spells a pop-up trigger of its own"
            )
        }
        let body = try #require(
            SourceScan.declarationBody(
                after: "struct UpdatePopUp",
                in: try Self.source("UpdatePopUp.swift")
            ),
            "UpdatePopUp is gone"
        )
        let flat = Self.flat(body)
        #expect(
            flat.contains(
                ".pickerStyle(.inline).labelsHidden()}label:{"
            ),
            "the Menu's Picker is no longer inline"
        )
        #expect(
            flat.contains(
                "}.menuStyle(.button).settingsPopUpTrigger()"
                    + ".neutralMenuLabel().menuIndicator(.hidden)"
                    + ".updateControlGround(Capsule())"
            ),
            "the Menu's own chain lost its ground"
        )
    }

    @Test(
        "each selector draws the pop-up",
        arguments: [
            "WhatsNewReleasePicker.swift", "UpdateNotesTabStrip.swift",
        ]
    )
    func selectorsDrawThePopUp(file: String) throws {
        #expect(try Self.source(file).contains("UpdatePopUp("))
    }

    /// The shown strip, not the hidden one sizing it.
    @Test("the tab strip's segments stand on the ground")
    func segmentsStandOnTheGround() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "var body",
                in: try Self.source("UpdateNotesTabStrip.swift")
            ),
            "the strip's body is gone"
        )
        #expect(
            Self.flat(body).contains(
                "SegmentedPicker(selection:$selection,options:options)"
                    + ".fixedSize().updateControlGround(Capsule())"
            )
        )
    }

    /// `card` is the ground the contrast suite measures the faces
    /// on; another fill would be a ground nobody measures.
    @Test("the ground is card")
    func groundIsCard() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func updateControlGround",
                in: try Self.source("UpdateControlGround.swift")
            ),
            "updateControlGround is gone"
        )
        #expect(
            Self.flat(body).contains("shape.fill(SettingsTheme.card)")
        )
    }
}
