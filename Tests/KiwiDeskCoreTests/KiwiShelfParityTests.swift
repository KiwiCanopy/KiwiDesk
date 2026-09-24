import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Structural guards for `KiwiShelf` (#1517), the `SpaceBarStyle`
/// shape: every field has a CodingKey, survives a round-trip and
/// is reachable by a `kiwishelf.set_*` verb.
@Suite("KiwiShelf field-list parity")
struct KiwiShelfParityTests {
    @Test("KiwiShelf CodingKeys cover every field")
    func keyParity() {
        #expect(
            keyStrings(KiwiShelf.CodingKeys.allCases)
                == Set(fieldNames(KiwiShelf()).map(snakeCased))
        )
    }

    @Test("Round-trip fixture sets every field")
    func fixtureIsExhaustive() {
        expectAllChanged(
            AppBarFixtures.everyShelfField(),
            from: KiwiShelf()
        )
    }

    @Test("Every field survives a JSON round-trip")
    func codableRoundTrip() throws {
        let shelf = AppBarFixtures.everyShelfField()
        let data = try JSONEncoder().encode(shelf)
        #expect(
            try JSONDecoder().decode(KiwiShelf.self, from: data)
                == shelf
        )
    }

    @Test("Missing keys decode to defaults")
    func sparseDecode() throws {
        #expect(
            try JSONDecoder().decode(
                KiwiShelf.self,
                from: Data("{}".utf8)
            ) == KiwiShelf()
        )
    }

    /// The looks reach both halves by member lookup, which picks
    /// ONE root per name — a field on both would make one of them
    /// unreachable through the look, silently.
    @Test("A look's two halves share no field")
    func looksAreDisjoint() {
        let shelf = fieldNames(KiwiShelf())
        #expect(shelf.isDisjoint(with: fieldNames(SpaceBarStyle())))
        #expect(shelf.isDisjoint(with: fieldNames(AppBarStyle())))
    }
}

/// Parity for `KiwiShelfCommandSetting`: every case writes
/// exactly one field, every field is reachable, and the
/// `kiwishelf` namespace lists exactly the fields' verbs.
@Suite("KiwiShelf command apply parity")
struct KiwiShelfCommandParityTests {
    private static let everySetting: [KiwiShelfCommandSetting] = [
        .edge(.left), .alignment(.end), .order(.appsFirst),
        .share(60), .thickness(44), .outerMargin(4),
        .innerMargin(6), .backgroundStyle(.boxed),
        .liquidGlass(false), .backgroundFit(.full),
        .cornerRoundness(5), .itemGap(3), .fontSize(15),
    ]

    @Test("Each command sets exactly one field")
    func applyParity() {
        var touched: Set<String> = []
        for setting in Self.everySetting {
            var shelf = KiwiShelf()
            setting.apply(to: &shelf)
            let changed = changedFields(shelf, from: KiwiShelf())
            #expect(changed.count == 1)
            touched.formUnion(changed)
        }
        #expect(touched == fieldNames(KiwiShelf()))
    }

    @Test("Parse accepts every field's spelling")
    func parseCoverage() {
        for key in KiwiShelf.CodingKeys.allCases {
            let parsed = KiwiShelfCommandSetting.parse(
                field: key.stringValue,
                args: sampleArgs(for: key)
            )
            #expect(
                (try? parsed.get()) != nil,
                "parse rejected \(key.stringValue)"
            )
        }
    }

    @Test("The kiwishelf namespace mirrors KiwiShelf's keys")
    func namespaceParity() {
        let expected = Set(
            KiwiShelf.CodingKeys.allCases.map {
                "set_\($0.stringValue)"
            }
        )
        #expect(
            Set(APIReference.namespaces["kiwishelf"] ?? [])
                == expected
        )
    }

    @Test("Share clamps to its range")
    func shareClamps() {
        var shelf = KiwiShelf()
        KiwiShelfCommandSetting.share(95).apply(to: &shelf)
        #expect(shelf.share == KiwiShelf.shareRange.upperBound)
        KiwiShelfCommandSetting.share(-5).apply(to: &shelf)
        #expect(shelf.share == KiwiShelf.shareRange.lowerBound)
    }

    private func sampleArgs(
        for key: KiwiShelf.CodingKeys
    ) -> [JSONValue] {
        switch key {
        case .liquidGlass: return [.bool(false)]
        case .edge: return [.string("left")]
        case .alignment: return [.string("end")]
        case .order: return [.string("apps_first")]
        case .backgroundStyle: return [.string("boxed")]
        case .backgroundFit: return [.string("full")]
        case .share, .thickness, .outerMargin, .innerMargin,
            .cornerRoundness, .itemGap, .fontSize:
            return [.number(30)]
        }
    }
}
