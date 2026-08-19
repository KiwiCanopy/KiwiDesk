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

    /// The copy-appearance contract (#293): every CodingKey
    /// the two styles share — minus the two named exclusions —
    /// is copied, and nothing else moves. Discovery is by key
    /// intersection, never a hand list, so a field added to
    /// both styles joins the copy or turns this red.
    /// The REVERSED direction (owner flip 2026-08-10): the
    /// App Bar card's button pulls Space Bar → App Bar. Same
    /// contract surface — `SpaceBarStyle.copyAppearanceKeys`
    /// is deliberately the one key set for both directions —
    /// so this is the twin of the test above: every shared
    /// key must change a field on the App Bar target too, or
    /// the mirrored switch silently skipped one.
    @Test("copy appearance fills every shared field reversed")
    func copyAppearanceParityReversed() {
        // A source Space Bar differing from App Bar defaults
        // on every copyable field: seed it through the proven
        // forward copy from the every-field fixture.
        var source = SpaceBarStyle()
        source.copyAppearance(
            from: AppBarFixtures.everyGlobalField()
        )
        var target = AppBarStyle()
        target.copyAppearance(from: source)
        let changed = changedFields(target, from: AppBarStyle())
        let expected = Set(
            SpaceBarStyle.copyAppearanceKeys.compactMap {
                key -> String? in
                fieldNames(AppBarStyle()).first {
                    snakeCased($0) == key
                }
            }
        )
        #expect(changed == expected)
        // The exclusions stay untouched.
        #expect(target.edge == AppBarStyle().edge)
    }

    @Test("Copy-appearance covers exactly the shared keys")
    func copyAppearanceParity() {
        // Source differs from the default target on EVERY
        // field, so an uncopied shared field is visible.
        let source = AppBarFixtures.everyGlobalField()
        var target = SpaceBarStyle()
        target.copyAppearance(from: source)
        let changed = changedFields(target, from: SpaceBarStyle())
        let expected = Set(
            SpaceBarStyle.copyAppearanceKeys.map { key in
                SpaceBarStyle.CodingKeys.allCases.first {
                    $0.stringValue == key
                }
            }
            .compactMap { key -> String? in
                guard let key else { return nil }
                return fieldNames(SpaceBarStyle()).first {
                    snakeCased($0) == key.stringValue
                }
            }
        )
        #expect(changed == expected)
        // The exclusions stay untouched.
        #expect(target.enabled == SpaceBarStyle().enabled)
        #expect(target.edge == SpaceBarStyle().edge)
        // Sanity: the intersection is non-trivial, and the
        // colour class is excluded wholesale (owner ruling
        // 2026-08-02: a colours-copy, if any, belongs to
        // Advanced Colours) — derived by suffix, so a new
        // shared colour field stays out automatically.
        #expect(
            SpaceBarStyle.copyAppearanceKeys.contains(
                "thickness"
            )
        )
        #expect(!SpaceBarStyle.sharedColorKeys.isEmpty)
        #expect(
            SpaceBarStyle.copyAppearanceKeys.isDisjoint(
                with: SpaceBarStyle.sharedColorKeys
            )
        )
        #expect(
            SpaceBarStyle.sharedColorKeys.contains("item_color")
        )
        // The space-only fields never join either set.
        #expect(
            !SpaceBarStyle.sharedColorKeys.contains(
                "focused_item_color"
            )
        )
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
        .enabled(false), .edge(.bottom), .alignment(.end),
        .thickness(44),
        .itemSize(120), .itemGap(3), .fontSize(15),
        .glyphCap(8), .titleCap(40),
        .iconSource(.appFont), .backgroundStyle(.boxed),
        .liquidGlass(true),
        .backgroundFit(.full),
        .activeIndicator(.gap), .cornerRoundness(5),
        .dimFactor(0.3), .activeDimFactor(0.7),
        .showFrontApp(true), .hideEmpty(true),
        .stickyBadge(false),
        .springDelay(1000),
        .itemColor("#010101"), .activeItemColor("#020202"),
        .focusedItemColor("#030303"), .hoverFillColor("#040404"),
        .hoverItemColor("#050505"), .fillColor("#060606"),
        .highlightColor("#080808"),
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
                field: "item_color",
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
        case .enabled, .showFrontApp, .hideEmpty,
            .stickyBadge, .liquidGlass:
            return [.bool(true)]
        case .edge: return [.string("bottom")]
        case .alignment: return [.string("end")]
        case .iconSource: return [.string("app_font")]
        case .backgroundStyle: return [.string("boxed")]
        case .backgroundFit: return [.string("full")]
        case .activeIndicator: return [.string("gap")]
        case .thickness, .itemSize, .itemGap, .fontSize,
            .cornerRoundness, .dimFactor, .activeDimFactor:
            return [.number(10)]
        case .springDelay: return [.number(1000)]
        case .glyphCap: return [.number(8)]
        case .titleCap: return [.number(40)]
        default:
            return [.string("#123456")]
        }
    }
}
