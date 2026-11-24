import Foundation
import Testing

/// The per-screen wiring no behaviour suite reaches (#1948, #3612):
/// each bar row's `?` while its screens differ, and Each bar and
/// Pocket held open only while the bars' own values differ, its
/// chevron greyed while held.
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

    @Test("each bar row explains an empty selection")
    func barRowsCarryTheirHelp() throws {
        let card = try squashed(Self.bars + "Bars/KiwiShelfCard+Edge.swift")
        // Each row points at the picker, and asks of its own screens.
        let rows = [
            ("spaceBarStyle", "BarsGateHelp.screensDiffer"),
            ("appBarStyle", "BarsGateHelp.screensDiffer"),
            ("kiwishelf.pocketEdges", "BarsGateHelp.pocketScreensDiffer"),
        ]
        #expect(count("help:screensDifferHelp(", in: card) == rows.count)
        for (owner, sentence) in rows {
            #expect(
                count(
                    "selection:model.barEdge(\\.\(owner)),"
                        + "options:edgeOptions,"
                        + "help:screensDifferHelp(\\.\(owner),\(sentence))",
                    in: card
                ) == 1
            )
        }
        // The `?` only while that owner's screens differ.
        #expect(
            count(
                "guardmodel.config.settings[keyPath:bar].screensDiffer"
                    + "else{returnnil}returnsentence()",
                in: card
            ) == 1
        )
    }

    @Test("a drawer held open greys its chevron")
    func lockedDrawersGreyTheirChevron() throws {
        let each = try squashed(Self.bars + "Bars/KiwiShelfCard+Each.swift")
        #expect(count("locked:eachHeldOpen", in: each) == 1)
        // Core's verdicts on the bars' own values, never a screen's
        // (#3612); `OwnShelfVerdictTests` holds what they answer.
        #expect(
            count(
                "returnsettings.ownBarVisibility==nil"
                    + "||settings.ownShelfEdge==nil}",
                in: each
            ) == 1
        )
        let wrapper = try squashed(
            Self.bars + "Common/SettingsDisclosure.swift"
        )
        // The hop from the drawer into its style.
        #expect(
            count(
                "SettingsDisclosureStyle(summary:summary,locked:locked,",
                in: wrapper
            ) == 1
        )
        let style = try squashed(
            Self.bars + "Common/SettingsDisclosureStyle.swift"
        )
        // Held open, deaf to a press: the button is the one home.
        #expect(
            count("ifconfiguration.isExpanded||locked{", in: style) == 1
        )
        #expect(count("guard!lockedelse{return}", in: style) == 1)
        #expect(count(".allowsHitTesting(!locked)", in: style) == 1)
        // A locked chevron takes another theme ink than an open
        // one — which two is a tuning.
        let ink = try Regex(
            #"\.foregroundStyle\(locked\?SettingsTheme\.(\w+)"#
                + #":SettingsTheme\.(\w+)\)"#
        )
        let inks = style.matches(of: ink)
        #expect(inks.count == 1)
        if let arms = inks.first?.output {
            #expect(arms[1].substring != arms[2].substring)
        }
    }
}
