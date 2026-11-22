import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A refused Hyper key leaves the recorder's width alone: the
/// card draws the reason across the row, so the trailing-pinned
/// button cannot jump left (#1870). `@MainActor` for the renderer.
@Suite("Hyper key field width")
@MainActor
struct HyperKeyFieldWidthTests {
    /// Hosts the field with the focus binding it needs.
    private struct Host: View {
        let refused: Bool
        @FocusState private var focused: Bool

        var body: some View {
            HyperKeyField(
                key: .constant(nil),
                refused: .constant(refused),
                disabled: false,
                focus: $focused
            )
        }
    }

    private func width(refused: Bool) throws -> CGFloat {
        let sized = Host(refused: refused)
            .environmentObject(RecorderCoordinator())
            .background(Color.white)
            .fixedSize()
        return try #require(ImageRenderer(content: sized).nsImage)
            .size.width
    }

    @Test("the refusal does not widen the recorder")
    func refusalKeepsTheWidth() throws {
        let plain = try width(refused: false)
        #expect(plain > 0)
        #expect(try width(refused: true) == plain)
    }

    /// The card owns the line and hands the field its state; the
    /// field clears it as it leaves.
    @Test("the card draws the refusal the field reports")
    func cardOwnsTheRefusal() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
            )
        let read = { (name: String) throws -> String in
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
        }
        let card = try read("ModifierKeysCard.swift")
        #expect(card.contains("ifhyperRefused{refusal}"))
        #expect(card.contains("refused:$hyperRefused,"))
        let field = try read("HyperKeyField.swift")
        #expect(field.contains(".onDisappear{refused=falsestop()}"))
    }
}
