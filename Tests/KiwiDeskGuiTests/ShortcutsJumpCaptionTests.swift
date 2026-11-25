import Foundation
import Testing

@testable import KiwiDesk

/// The jump bar's caption (#1520 amendment 6): every line starts at
/// the leading inset, the caption rides over the chips and goes at
/// the chrome step, drawn and silent to VoiceOver. The bar names no
/// layer: the strip above the switcher does (#3535).
@Suite("Shortcuts jump caption")
struct ShortcutsJumpCaptionTests {
    @Test("the row leads under its caption, naming no layer")
    func rowLeads() throws {
        let bar = try Self.source(
            "Components/Keybindings/ShortcutsJumpBar.swift"
        )
        #expect(bar.contains("FlowLayout(spacing:Self.spacing){"))
        #expect(!bar.contains("FlowLayout(spacing:Self.spacing,alignment"))
        #expect(bar.contains(".frame(maxWidth:.infinity,alignment:.leading)"))
        #expect(
            bar.contains(
                "VStack(alignment:.leading,spacing:Self.spacing){"
                    + "if!width.collapsesChrome{caption}chips}"
            )
        )
        // The caption's font and ink are tunings; a theme ink and
        // its hiding from VoiceOver are the shape.
        let caption = try Regex(
            #"Text\(label\)\.font\((?:[^()]|\([^()]*\))*\)"#
                + #"\.foregroundStyle\(SettingsTheme\.\w+\)"#
                + #"\.lineLimit\(1\)\.fixedSize\(\)"#
                + #"\.accessibilityHidden\(true\)"#
        )
        #expect(bar.contains(caption))
        #expect(!bar.contains("readout"))
        let jump = try Self.source("Sections/ShortcutsSection+Jump.swift")
        #expect(!jump.contains("shortcuts.editing_layer"))
    }

    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }
}
