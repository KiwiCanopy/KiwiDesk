import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// **The Liquid Glass group's Fill rows and "No Color"** (#2569 ▸
/// Ruling): "No Color" is the Fill at zero opacity with its hue
/// kept; the Tint and Fill fade rows grey while the switch is off
/// or the Fill has no colour, the reason said inline under the
/// slider. The greys and the menu item are wiring no behavioural
/// test can reach, so they are needled on their use sites.
@Suite("Liquid Glass Fill rows (#2569)")
struct GlassSettingsRowsTests {
    private static let gui = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk/Settings")

    private static func squashed(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: gui.appendingPathComponent(path)
        ).filter { !$0.isWhitespace }
    }

    @Test(
        "No Color keeps the hue at zero opacity",
        arguments: [
            ("#14201CB3", "#14201C00"), ("#FF9F43", "#FF9F4300"),
            ("", "#00000000"), ("nope", "#00000000"),
        ]
    )
    func noColorKeepsTheHue(hex: String, cleared: String) {
        #expect(ColorSwatch.cleared(hex) == cleared)
        #expect(!KiwiShelf.hasColour(ColorSwatch.cleared(hex)))
    }

    @Test("The Fill's rows are the Tint switch and Fill fade")
    @MainActor
    func fillRows() {
        let rows = ColorsRowOrder.glassRows.filter {
            GlassCard.followsTheFill($0)
        }
        #expect(
            rows == [.kiwishelf(.tintHubAndPlates), .kiwishelf(.fillFade)]
        )
    }

    @Test("The rows grey on the switch and the Fill, and say why")
    func greysAreWired() throws {
        let card = try Self.squashed("Components/Looks/GlassCard.swift")
        #expect(card.contains("(Self.followsTheFill(key)&&fillIdle)"))
        #expect(
            card.contains(
                "!model.liquidGlassMaster.wrappedValue||!shelf.hasFill"
            )
        )
        #expect(
            card.contains(
                "key==.kiwishelf(.fillFade),model.liquidGlassMaster"
                    + ".wrappedValue,!shelf.hasFill"
            )
        )
        #expect(card.contains("Text(noColourHelp)"))
    }

    @Test("The Fill well offers No Color, and only it")
    func onlyTheFillIsClearable() throws {
        let bars = try Self.squashed(
            "Components/Colors/ColorsAndGlassRow+Bars.swift"
        )
        #expect(
            bars.components(separatedBy: "clearable:true").count - 1 == 1
        )
        let menu = try Self.squashed(
            "Components/Common/ColorField+AutomaticMenu.swift"
        )
        #expect(
            menu.contains("ifclearable{noColourItem(hex:hex,draft:draft)}")
        )
        #expect(menu.contains("ColorSwatch.cleared(hex.wrappedValue)"))
    }
}
