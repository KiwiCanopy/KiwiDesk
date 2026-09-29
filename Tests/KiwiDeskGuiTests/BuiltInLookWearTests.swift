import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A built-in applies wearing the shared look (#1752), so a picture
/// of one wears it too: a reader of `StandardLayout.settings(sizes:)`
/// in the GUI paints the look over it through `LookBody.worn(over:)`
/// or draws colours and gaps the applied built-in will not have
/// (profiles.md, gui.md #702).
@Suite("Built-in look wear (#1752)")
struct BuiltInLookWearTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File → how its read of a built-in's settings wears the look.
    private static let allowed: [String: String] = [
        "PresetPreviewSheet.swift":
            "`drawnSettings` wears the handed look, pinned below"
    ]

    /// A call of `settings(sizes:)`, implicit `self` and spacing
    /// included.
    private static var read: Regex<Substring> {
        #/(?:^|[^A-Za-z0-9_])settings\(\s*sizes\s*:/#
    }

    private static let settingsDir = root.appendingPathComponent(
        "Sources/KiwiDesk/Settings"
    )

    private func squashed(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: Self.settingsDir.appendingPathComponent(path),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    @Test("the preset sheet draws a built-in wearing the shared look")
    @MainActor func theSheetWearsTheSharedLook() throws {
        // A preset the default look does not already wear, so a nil
        // path that paints the default is seen too.
        let plain = LookBody(of: TilingSettings())
        let layout = try #require(
            StandardProfiles.workflows.first {
                !plain.isWorn(by: $0.settings(sizes: nil))
            }
        )
        let raw = layout.settings(sizes: nil)
        var painted = raw
        painted.kiwishelf.fillColor = "#0A0B0C"
        painted.gapsGlobal.inner.horizontal += 7
        let look = LookBody(of: painted)
        let sheet = PresetPreviewSheet(
            layout: layout,
            liveSizes: nil,
            sharedLook: look
        ) {}
        #expect(sheet.drawnSettings != raw)
        #expect(sheet.drawnSettings.kiwishelf.fillColor == "#0A0B0C")
        #expect(sheet.drawnSettings.gapsGlobal == painted.gapsGlobal)
        // The paint and its inverse agree.
        #expect(look.isWorn(by: sheet.drawnSettings))
        // No shared look: the preset's own settings, untouched.
        let bare = PresetPreviewSheet(
            layout: layout,
            liveSizes: nil,
            sharedLook: nil
        ) {}
        #expect(bare.drawnSettings == raw)
    }

    /// The look reaches the tile: the card hands the committed one,
    /// the section forwards it, and the tile draws the worn value.
    @Test("the shared look is wired from the card to the tile")
    func theLookIsWired() throws {
        let sheet = try squashed(
            "Components/Profiles/PresetPreviewSheet.swift"
        )
        #expect(sheet.occurrences(of: "sharedLook?.worn(over:own)") == 1)
        #expect(sheet.occurrences(of: "settings:drawnSettings") == 1)
        let section = try squashed("Sections/PresetsSection.swift")
        #expect(
            section.occurrences(of: "sharedLook:request.sharedLook") == 1
        )
        let card = try squashed("Components/Profiles/PresetCard.swift")
        #expect(
            card.occurrences(of: "sharedLook:model.core.sharedLook") == 1
        )
    }

    /// A new GUI reader of a built-in's settings reds until it wears
    /// the look and is given its reason above.
    @Test("every GUI read of a built-in's settings is registered")
    func everyReadIsRegistered() throws {
        let files = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Sources/KiwiDesk")
        )
        #expect(!files.isEmpty)
        var readers: Set<String> = []
        for file in files {
            let text = try SourceScan.strippedSource(at: file)
            if text.firstMatch(of: Self.read) != nil {
                readers.insert(file.lastPathComponent)
            }
        }
        #expect(readers == Set(Self.allowed.keys))
    }
}
