import Foundation
import Testing

@testable import KiwiDesk

/// Which overlay panels span macOS Desktops. The sticky mark
/// always does: it draws only on sticky windows, which the
/// Desktop reach carries (#1145), and a single-Desktop panel
/// strands it on the origin (device-observed 2026-09-01). The
/// focus ring does NOT by default: spanning, it stood on screen
/// through every Desktop switch's slide (#2149), so it joins every
/// Desktop only while its window is carried. A source scan,
/// because a headless suite cannot order a panel onto a Space.
@Suite("Overlay panels span Desktops only where they follow")
struct StickyOverlaySpanTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// The `panel.collectionBehavior = [...]` literal of `file`.
    private func behaviorLiteral(_ file: String) throws -> String? {
        let url = Self.root.appendingPathComponent(file)
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .filter { !$0.isWhitespace }
        return source.components(
            separatedBy: "panel.collectionBehavior=["
        )
        .dropFirst().first?
        .components(separatedBy: "]").first
    }

    @Test("the sticky mark joins all Spaces")
    func markJoinsAllSpaces() throws {
        let literal = try behaviorLiteral(
            "Sources/KiwiDeskCore/Borders/StickyMarkOverlay.swift"
        )
        #expect(literal?.contains(".canJoinAllSpaces") == true)
    }

    /// A KiwiVision plate dims a whole screen whichever Desktop it
    /// shows, so it joins every Desktop (#2103).
    @Test("a KiwiVision plate joins all Spaces")
    func plateJoinsAllSpaces() throws {
        let literal = try behaviorLiteral(
            "Sources/KiwiDeskCore/Vision/VisionPlate.swift"
        )
        #expect(literal?.contains(".canJoinAllSpaces") == true)
        #expect(literal?.contains(".transient") == true)
    }

    /// A float's KiwiVision veil follows one float, so it is the
    /// ring's kind: one Desktop, joining every Desktop only while
    /// its float is carried (#2103 ruling 3, #2149).
    @Test("a float veil is built on one Desktop and spans when carried")
    func floatVeilSpansOnlyWhenCarried() throws {
        let literal = try behaviorLiteral(
            "Sources/KiwiDeskCore/Vision/FloatDimPanel.swift"
        )
        #expect(literal?.contains(".transient") == true)
        #expect(literal?.contains(".canJoinAllSpaces") == false)
        let core = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+VisionFloats.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(core.contains("spans: carried.contains(id)"))
    }

    @Test("the ring is built on one Desktop and spans when carried")
    func ringSpansOnlyWhenCarried() throws {
        let literal = try behaviorLiteral(
            "Sources/KiwiDeskCore/Borders/AppKitBorderOverlay.swift"
        )
        #expect(literal != nil)
        #expect(literal?.contains(".canJoinAllSpaces") == false)
        let core = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+Borders.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(core.contains("spansDesktops: carried.contains(spec.window)"))
        #expect(core.contains("desktop: shownDesktop(at: frame)"))
        let sync = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDeskCore/Borders/BorderManager+Sync.swift"
                ),
                encoding: .utf8
            )
        )
        let handler = SourceScan.stripComments(
            try String(
                contentsOf: Self.root.appendingPathComponent(
                    "Sources/KiwiDeskCore/Profiles/KiwiCore+Desktops.swift"
                ),
                encoding: .utf8
            )
        )
        #expect(
            handler.contains(
                "let snapshot = stampedDesktopSnapshot()\n"
                    + "        desktopMemory.shownSpaces = "
                    + "snapshot.currentSpaces"
            )
        )
        #expect(
            sync.filter { !$0.isWhitespace }.contains(
                "overlay.place(spansDesktops:spec.spansDesktops,"
                    + "desktop:spec.desktop)"
            )
        )
    }
}
