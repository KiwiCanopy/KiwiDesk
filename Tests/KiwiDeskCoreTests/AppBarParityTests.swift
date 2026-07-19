import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// Exhaustive fixtures live in `AppBarFixtures.swift`, shared with
// the round-trip in `AppBarTests`.

/// Structural parity for the `AppBarStyle` ↔ `LayoutAppBar`
/// mirror (#73). A new `AppBarStyle` field that is forgotten in
/// `LayoutAppBar`, either type's `CodingKeys`, `resolved(with:)`,
/// or the round-trip fixtures becomes a red build here — not a
/// silent inherit-the-default bug (AGENTS.md §5).
@Suite("App bar field-list parity")
struct AppBarParityTests {
    @Test("LayoutAppBar mirrors every AppBarStyle field")
    func propertyParity() {
        // `enabled` is the one layout-only field; every look
        // field is an optional override of the global style.
        #expect(
            fieldNames(LayoutAppBar()).subtracting(["enabled"])
                == fieldNames(AppBarStyle())
        )
    }

    @Test("AppBarStyle CodingKeys cover every field")
    func styleKeyParity() {
        #expect(
            keyStrings(AppBarStyle.CodingKeys.allCases)
                == Set(fieldNames(AppBarStyle()).map(snakeCased))
        )
    }

    @Test("LayoutAppBar CodingKeys cover every field")
    func barKeyParity() {
        #expect(
            keyStrings(LayoutAppBar.Key.allCases)
                == Set(fieldNames(LayoutAppBar()).map(snakeCased))
        )
    }

    /// The override fixture differs from the base fixture on every
    /// field, so a forgotten `if let` in `resolved(with:)` leaves
    /// that field at the base value and this goes red.
    @Test("resolved(with:) applies every override field")
    func resolveParity() {
        let base = AppBarFixtures.everyGlobalField()
        let resolved =
            AppBarFixtures.everyOverrideField().resolved(with: base)
        let baseValues = fieldValues(base)
        for (field, value) in fieldValues(resolved) {
            #expect(
                value != baseValues[field],
                "resolved() left \(field) at the base value"
            )
        }
    }

    /// The `AppBarTests` round-trip is only forget-proof if its
    /// fixtures touch every field. Reflection pins that here.
    @Test("Round-trip fixtures set every field")
    func fixturesAreExhaustive() {
        expectAllChanged(
            AppBarFixtures.everyGlobalField(),
            from: AppBarStyle()
        )
        expectAllChanged(
            AppBarFixtures.everyOverrideField(),
            from: LayoutAppBar()
        )
    }
}

/// Parity for `AppBarCommandSetting`'s dual apply switches (#73).
/// Both switches are exhaustive over the same enum, so the
/// compiler already forces a new case into both; this pins the
/// rest: every case writes the *same, single* field on style and
/// bar, and every `AppBarStyle` field is command-reachable.
@Suite("App bar command apply parity")
struct AppBarCommandParityTests {
    /// One representative setting per case, each value chosen to
    /// differ from the field's default so the write is visible.
    /// `applyParity` goes red if this list, either apply switch,
    /// or `AppBarStyle` drift apart.
    private static let everySetting: [AppBarCommandSetting] = [
        .edge(.bottom), .alignment(.end), .thickness(50),
        .tabBackground(.plain), .tabBackgroundFit(.full),
        .activeIndicator(.gap),
        .boxSize(88), .boxGap(9),
        .content(.name), .iconSource(.appFont),
        .groupAdjacentWindows(false),
        .fontSize(20), .cornerRoundness(12),
        .textColor("#111111"), .boxColor("#222222"),
        .activeTextColor("#333333"), .activeBoxColor("#444444"),
        .highlightColor("#555555"), .hoverColor("#666666"),
        .hoverTextColor("#777777"), .backgroundColor("#888888"),
        .groupBadgeColor("#999999"),
        .groupBadgeTextColor("#AAAAAA"),
    ]

    @Test("Each command sets one matching field on style and bar")
    func applyParity() {
        var touched: Set<String> = []
        for setting in Self.everySetting {
            var style = AppBarStyle()
            var bar = LayoutAppBar()
            setting.apply(to: &style)
            setting.apply(to: &bar)
            let onStyle = changedFields(style, from: AppBarStyle())
            // `enabled` is bar-only, never a command target.
            let onBar = changedFields(bar, from: LayoutAppBar())
                .subtracting(["enabled"])
            #expect(onStyle.count == 1)
            #expect(onStyle == onBar)
            touched.formUnion(onStyle)
        }
        // Every look field must be reachable by some command. If
        // a future field is intentionally not command-settable,
        // give it an exclusion set here (cf. the override tests'
        // `notOverridable`) rather than dropping the assert.
        #expect(touched == fieldNames(AppBarStyle()))
    }
}
