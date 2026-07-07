import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Fixtures that set *every* field to a non-default value. Shared
/// by the JSON round-trip in `AppBarTests` and the reflection
/// guards below, so there is a single mirror of the field list to
/// keep honest (`AppBarParityTests.fixturesAreExhaustive` pins it).
enum AppBarFixtures {
    static func everyGlobalField() -> AppBarStyle {
        var style = AppBarStyle()
        style.position = .bottom
        style.thickness = 44
        style.style = .segments
        style.activeStyle = .gap
        style.itemSize = 120
        style.itemGap = 3
        style.content = .name
        style.groupAdjacentWindows = false
        style.fontSize = 15
        style.cornerRadius = 5
        style.textColor = "#010101"
        style.boxColor = "#020202"
        style.activeTextColor = "#030303"
        style.activeBoxColor = "#040404"
        style.highlightColor = "#050505"
        style.hoverColor = "#060606"
        style.hoverTextColor = "#070707"
        style.backgroundColor = "#080808"
        style.groupBadgeColor = "#090909"
        style.groupBadgeTextColor = "#0A0A0A"
        return style
    }

    static func everyOverrideField() -> LayoutAppBar {
        var bar = LayoutAppBar()
        bar.enabled = false
        bar.position = .right
        bar.thickness = 50
        bar.style = .underline
        bar.activeStyle = .highlight
        bar.itemSize = 88
        bar.itemGap = 9
        bar.content = .iconAndName
        bar.groupAdjacentWindows = true
        bar.fontSize = 20
        bar.cornerRadius = 12
        bar.textColor = "#111111"
        bar.boxColor = "#222222"
        bar.activeTextColor = "#333333"
        bar.activeBoxColor = "#444444"
        bar.highlightColor = "#555555"
        bar.hoverColor = "#666666"
        bar.hoverTextColor = "#777777"
        bar.backgroundColor = "#888888"
        bar.groupBadgeColor = "#999999"
        bar.groupBadgeTextColor = "#AAAAAA"
        return bar
    }
}

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
        .position(.right), .thickness(50), .style(.underline),
        .activeStyle(.gap), .itemSize(88), .itemGap(9),
        .content(.name), .groupAdjacentWindows(false),
        .fontSize(20), .cornerRadius(12),
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
        // Every look field must be reachable by some command.
        #expect(touched == fieldNames(AppBarStyle()))
    }
}
