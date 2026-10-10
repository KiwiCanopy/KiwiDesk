import Foundation
import Testing

/// The Per screen wiring no behaviour suite reaches (#1948): both
/// drawers mount only while the profile holds more than one screen
/// (hidden, never greyed), and a drawer held open by what it shows
/// greys its chevron — Each bar's and each Per screen drawer's.
@Suite("Per screen wiring (#1948)")
struct ScreenEdgesWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let bars = "Sources/KiwiDesk/Settings/Components/"

    private func squashed(_ repoRelative: String) throws -> String {
        let url = Self.root.appendingPathComponent(repoRelative)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    private func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("each drawer mounts only while the profile holds two screens")
    func drawersHideOnOneScreen() throws {
        let card = try squashed(Self.bars + "Bars/KiwiShelfCard+Edge.swift")
        #expect(count("ScreenEdgesDrawer(", in: card) == 2)
        #expect(
            count(
                "ifmodel.offersScreenEdges{ScreenEdgesDrawer(",
                in: card
            ) == 2
        )
    }

    @Test("a drawer held open greys its chevron")
    func lockedDrawersGreyTheirChevron() throws {
        let card = try squashed(Self.bars + "Bars/KiwiShelfCard+Edge.swift")
        #expect(count("locked:edgesSplit", in: card) == 1)
        let drawer = try squashed(Self.bars + "Bars/ScreenEdgesDrawer.swift")
        #expect(count("locked:locked", in: drawer) == 1)
        #expect(
            count("get:{expanded||locked}", in: drawer) == 1
        )
        let style = try squashed(
            Self.bars + "Common/SettingsDisclosureStyle.swift"
        )
        #expect(
            count(
                ".foregroundStyle(locked?SettingsTheme.ink3"
                    + ":SettingsTheme.ink2)",
                in: style
            ) == 1
        )
    }
}
