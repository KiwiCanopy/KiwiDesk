import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// KiwiHub's footer row carries the side's buttons beside its key
/// hints, so in every shipped language the buttons and at least
/// the first hint fit the panel; the rest shed from the end.
/// Measured on the widest side — View, with a long profile name —
/// as AppKit sizes it. Spends one hosting measurement per piece
/// per locale on the main actor.
@Suite("KiwiHub footer fit")
@MainActor
struct JumpFooterFitTests {
    private static let unbounded = CGSize(width: 4000, height: 200)
    private static let profile = "Super Ultrawide"

    private static func locales() throws -> [String] {
        let directory = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
        let names = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )
        let codes = names.filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }
            .sorted()
        #expect(codes.count > 1, "no catalogs found")
        return codes
    }

    private func width(_ view: some View) -> CGFloat {
        NSHostingController(rootView: view.fixedSize())
            .sizeThatFits(in: Self.unbounded).width
    }

    /// What the row leaves its hints: the panel less its insets,
    /// the two buttons and the row's spacing.
    private func room() -> CGFloat {
        let settings = KeyPanelChordButton(
            title: ViewPickText.settings(.profile),
            chord: "⌘,"
        ) {}
        let keep = KeyPanelChordButton(
            title: LayoutPickText.keep(Self.profile),
            chord: "⌘S"
        ) {}
        let insets = 2 * (KeyPanelStyle.selectionInset + 10)
        return JumpPanelView.width - insets - 2 * 12
            - width(settings) - width(keep)
    }

    private func hintWidth(_ hints: [String]) -> CGFloat {
        let dots = Array(repeating: "·", count: max(hints.count - 1, 0))
        let pieces =
            hints.map { width(Text($0).font(.caption)) }
            + dots.map { width(Text(verbatim: $0).font(.caption)) }
        return pieces.reduce(0, +)
            + 8 * CGFloat(max(pieces.count - 1, 0))
    }

    @Test("the buttons and the first hint fit in every language")
    func buttonsAndFirstHintFit() throws {
        for code in try Self.locales() {
            LocalizationManager.shared.select(code)
            let hints = JumpFooter(scope: .view, overflows: false).hints
            let room = room()
            let kept =
                (0...hints.count).last {
                    hintWidth(Array(hints.prefix($0))) <= room
                } ?? 0
            print("footer fit \(code): \(kept)/\(hints.count) hints")
            #expect(kept >= 1, "\(code) leaves the hints \(room) pt")
        }
        LocalizationManager.shared.select("en")
    }
}
