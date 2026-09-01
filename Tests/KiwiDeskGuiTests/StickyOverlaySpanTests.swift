import Foundation
import Testing

@testable import KiwiDesk

/// The sticky mark and the focus ring span macOS Desktops
/// (#1145): a carried sticky window changes Desktop, and a
/// single-Desktop overlay panel strands its mark and ring on the
/// origin (device-observed 2026-09-01). The bars already carry
/// `.canJoinAllSpaces`, which is why the Space Bar spans
/// Desktops; the overlays take the same recipe. A source scan,
/// because a headless suite cannot order a panel onto a Space.
@Suite("Sticky overlays span Desktops")
struct StickyOverlaySpanTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// Both overlay panels, one needle each: the collection
    /// behavior literal carries the spanning flag — anywhere in
    /// the bracket, since its order is nothing this guard holds.
    private static let panels = [
        "Sources/KiwiDeskCore/Borders/StickyMarkOverlay.swift",
        "Sources/KiwiDeskCore/Borders/AppKitBorderOverlay.swift",
    ]

    @Test("every overlay panel joins all Spaces")
    func overlayPanelsJoinAllSpaces() throws {
        for file in Self.panels {
            let url = Self.root.appendingPathComponent(file)
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            let literal = source.components(
                separatedBy: "panel.collectionBehavior=["
            )
            .dropFirst().first?
            .components(separatedBy: "]").first
            #expect(
                literal?.contains(".canJoinAllSpaces") == true,
                Comment(
                    rawValue:
                        "\(file) no longer spans Desktops — a "
                        + "carried sticky window strands its "
                        + "overlay on the origin (#1145)"
                )
            )
        }
    }
}
