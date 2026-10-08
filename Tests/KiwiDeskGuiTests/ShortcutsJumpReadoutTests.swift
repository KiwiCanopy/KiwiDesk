import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The jump bar's layer readout (#1520), split from
/// `ShortcutsJumpTests` at the §2.1 ceiling: it never elides the
/// sentence — a long name is cut inside it — and it rides the
/// caption line over the chips.
/// Serialized: one clause pins the process-wide locale.
@Suite("Shortcuts jump readout", .serialized)
@MainActor
struct ShortcutsJumpReadoutTests {
    /// A long layer name is cut inside the sentence, so "Editing
    /// the … layer" always reads whole.
    @Test("a long layer name is cut, never the sentence")
    func longNameIsCut() {
        let limit = ShortcutsJumpBar.nameLimit
        let long = String(repeating: "x", count: limit + 10)
        let shown = ShortcutsJumpBar.shownName(long)
        #expect(shown.count == limit)
        #expect(shown.hasSuffix("…"))
        let short = String(repeating: "x", count: limit)
        #expect(ShortcutsJumpBar.shownName(short) == short)
    }

    private func barHeight(
        readout: String?,
        width: CGFloat,
        band: SettingsWidthClass = .medium
    ) throws -> CGFloat {
        let bar = ShortcutsJumpBar(
            tracker: ShortcutsJumpTracker(),
            readout: readout
        ) { _ in }
        .environment(\.settingsWidth, band)
        .frame(width: width)
        let image = try #require(ImageRenderer(content: bar).nsImage)
        return image.size.height
    }

    private func textSize(_ text: String) throws -> CGSize {
        try #require(
            ImageRenderer(
                content: Text(text).font(.callout).fixedSize()
            ).nsImage
        ).size
    }

    /// The readout rides the caption line over the chips, wrapping
    /// under the caption where both do not fit, and never elides.
    /// Derived rather than compared: the bar is the bare chips (the
    /// chrome step's bar at the same width) plus one gap and line
    /// per line of the caption's — a readout beside the chips would
    /// wrap or widen them instead, which "taller" cannot tell apart.
    @Test("the readout sits on the caption line over the chips")
    func readoutRidesTheCaptionLine() throws {
        // The chips' titles are translated text (#740).
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let name = ShortcutsJumpBar.shownName(
            String(repeating: "W", count: 40)
        )
        let readout = "Editing the \u{201C}\(name)\u{201D} layer"
        let gap = ShortcutsJumpBar.spacing
        let line = try textSize(readout).height
        let wide: CGFloat = 2000
        let wideBare = try barHeight(
            readout: nil,
            width: wide,
            band: .tight
        )
        // One caption line, with or without the readout on it.
        for shown in [readout, nil] as [String?] {
            let height = try barHeight(readout: shown, width: wide)
            #expect(abs(height - (wideBare + gap + line)) < 1)
        }
        // Too narrow for caption and readout side by side, wide
        // enough for the readout alone: it wraps under the caption.
        let readoutWidth = try textSize(readout).width
        let narrow = readoutWidth + 2 * SettingsMetrics.paneInset + gap
        let narrowBare = try barHeight(
            readout: nil,
            width: narrow,
            band: .tight
        )
        let height = try barHeight(readout: readout, width: narrow)
        #expect(abs(height - (narrowBare + 2 * (gap + line))) < 1)
    }

    /// Leading (#1520 amendment 6): every line starts at the
    /// leading inset. The caption line rides over the chips and
    /// goes at the chrome step; its caption draws the row's
    /// VoiceOver name, silent to VoiceOver, with the readout at
    /// its end. Shape, not value.
    @Test("the row leads under its caption line")
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
                    + "if!width.collapsesChrome{captionLine}chips}"
            )
        )
        #expect(bar.contains("L(\"shortcuts.jump.label\",\"Jumpto\")"))
        #expect(
            bar.contains(
                "Text(label).font(.callout)"
                    + ".foregroundStyle(SettingsTheme.ink2)"
                    + ".lineLimit(1).fixedSize()"
                    + ".accessibilityHidden(true)"
            )
        )
        // The caption, a spacer, the readout at the end: the
        // spacing and the spacer's minimum are tuning, not shape.
        let line = try Regex(
            #"HStack\(alignment:\.firstTextBaseline[^{]*\)\{"#
                + #"captionSpacer\([^)]*\)"#
                + #"readoutText\(readout\)\.fixedSize\(\)\}"#
        )
        #expect(bar.contains(line))
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
