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
        .backgroundStyle(.plain), .liquidGlass(true),
        .backgroundFit(.full),
        .activeIndicator(.gap),
        .itemSize(88), .itemGap(9),
        .content(.name), .iconSource(.appFont),
        .groupAdjacentWindows(false),
        .fontSize(20), .cornerRoundness(12), .dimFactor(0.3),
        .itemColor("#111111"), .fillColor("#222222"),
        .activeItemColor("#333333"),
        .highlightColor("#555555"), .hoverFillColor("#666666"),
        .hoverItemColor("#777777"),
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

    /// The `space_bar` twin of this lives in
    /// `SpaceBarCommandTests`. Without it the app-bar verb list
    /// in `APIReference` was a hand-typed mirror of the field
    /// list with no guard (AGENTS §5) — a stale entry registers a
    /// Lua function whose dispatch always fails, a missing one
    /// silently deletes a verb, and neither shows up in a build.
    @Test("The app_bar namespace mirrors AppBarStyle's keys")
    func appBarNamespaceParity() {
        let expected = Set(
            AppBarStyle.CodingKeys.allCases.map {
                "set_\($0.stringValue)"
            }
        )
        #expect(
            Set(APIReference.namespaces["app_bar"] ?? []) == expected
        )
    }

    /// The per-layout twins carry the same field list under a
    /// `set_app_bar_` prefix, and add `enabled` — the one
    /// `LayoutAppBar` field with no global counterpart.
    ///
    /// The layout list is hand-written, so it is asserted in BOTH
    /// directions: forward, that each named layout carries the
    /// whole field list; and backward, that no OTHER namespace
    /// has grown app-bar verbs. Without the reverse leg a third
    /// bar-hosting layout could ship a partial verb set and this
    /// guard would stay green — the "one more place to forget"
    /// shape AGENTS §5 warns about.
    @Test("Each bar-hosting layout mirrors LayoutAppBar's keys")
    func layoutAppBarNamespaceParity() {
        let expected = Set(
            LayoutAppBar.Key.allCases.map {
                "set_app_bar_\($0.stringValue)"
            }
        )
        let hosting = APIReference.namespaces.filter { _, verbs in
            verbs.contains { $0.hasPrefix("set_app_bar_") }
        }
        #expect(Set(hosting.keys) == ["monocle", "scroll"])
        for layout in ["monocle", "scroll"] {
            let verbs = Set(
                (APIReference.namespaces[layout] ?? [])
                    .filter { $0.hasPrefix("set_app_bar_") }
            )
            #expect(verbs == expected, "\(layout) app-bar verbs")
        }
    }
}
