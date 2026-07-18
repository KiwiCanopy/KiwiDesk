import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Structural guards for `SpaceBarStyle` (#293): every field has
/// a CodingKey, survives a round-trip, and is reachable by a
/// `space_bar.set_*` command. Global-only, so there is no
/// override mirror to guard — one fewer parity surface by
/// design.
@Suite("Space bar field-list parity")
struct SpaceBarParityTests {
    @Test("SpaceBarStyle CodingKeys cover every field")
    func keyParity() {
        #expect(
            keyStrings(SpaceBarStyle.CodingKeys.allCases)
                == Set(
                    fieldNames(SpaceBarStyle()).map(snakeCased)
                )
        )
    }

    @Test("Round-trip fixture sets every field")
    func fixtureIsExhaustive() {
        expectAllChanged(
            SpaceBarFixtures.everyField(),
            from: SpaceBarStyle()
        )
    }

    @Test("Every field survives a JSON round-trip")
    func codableRoundTrip() throws {
        let style = SpaceBarFixtures.everyField()
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: data
        )
        #expect(decoded == style)
    }

    @Test("Missing keys decode to defaults")
    func sparseDecode() throws {
        let decoded = try JSONDecoder().decode(
            SpaceBarStyle.self,
            from: Data("{}".utf8)
        )
        #expect(decoded == SpaceBarStyle())
    }
}

/// Parity for `SpaceBarCommandSetting`'s apply switch: every
/// case writes exactly one field, and every field is
/// command-reachable.
@Suite("Space bar command apply parity")
struct SpaceBarCommandParityTests {
    /// One representative setting per case, each value chosen
    /// to differ from the field's default so the write shows.
    private static let everySetting: [SpaceBarCommandSetting] = [
        .enabled(true), .edge(.bottom), .thickness(44),
        .itemSize(120), .itemGap(3), .fontSize(15),
        .iconSource(.appFont), .tabBackground(.plain),
        .activeIndicator(.gap), .cornerRoundness(5),
        .showFrontApp(true), .hideEmpty(true),
        .textColor("#010101"), .activeTextColor("#020202"),
        .focusedItemColor("#030303"), .hoverColor("#040404"),
        .hoverTextColor("#050505"), .boxColor("#060606"),
        .activeBoxColor("#070707"), .highlightColor("#080808"),
        .backgroundColor("#090909"),
        .groupBadgeColor("#0A0A0A"),
        .groupBadgeTextColor("#0B0B0B"),
    ]

    @Test("Each command sets exactly one field")
    func applyParity() {
        var touched: Set<String> = []
        for setting in Self.everySetting {
            var style = SpaceBarStyle()
            setting.apply(to: &style)
            let changed = changedFields(
                style,
                from: SpaceBarStyle()
            )
            #expect(changed.count == 1)
            touched.formUnion(changed)
        }
        #expect(touched == fieldNames(SpaceBarStyle()))
    }

    @Test("Parse accepts every field's spelling")
    func parseCoverage() {
        for key in SpaceBarStyle.CodingKeys.allCases {
            let args = sampleArgs(for: key)
            let parsed = SpaceBarCommandSetting.parse(
                field: key.stringValue,
                args: args
            )
            #expect(
                (try? parsed.get()) != nil,
                "parse rejected \(key.stringValue)"
            )
        }
    }

    @Test("Unknown fields and bad values are rejected")
    func parseRejections() {
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "nope",
                args: [.string("x")]
            ).get()) == nil
        )
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "edge",
                args: [.string("start")]
            ).get()) == nil
        )
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "text_color",
                args: [.string("red")]
            ).get()) == nil
        )
        #expect(
            (try? SpaceBarCommandSetting.parse(
                field: "enabled",
                args: [.string("yes")]
            ).get()) == nil
        )
    }

    /// A valid sample argument per key, by value kind.
    private func sampleArgs(
        for key: SpaceBarStyle.CodingKeys
    ) -> [JSONValue] {
        switch key {
        case .enabled, .showFrontApp, .hideEmpty:
            return [.bool(true)]
        case .edge: return [.string("bottom")]
        case .iconSource: return [.string("app_font")]
        case .tabBackground: return [.string("plain")]
        case .activeIndicator: return [.string("gap")]
        case .thickness, .itemSize, .itemGap, .fontSize,
            .cornerRoundness:
            return [.number(10)]
        default:
            return [.string("#123456")]
        }
    }
}
