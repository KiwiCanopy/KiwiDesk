import Testing

@testable import KiwiDesk

/// The drawn half of the Colors & glass search join (#2389,
/// #1250): `SettingsSearchIndex` lands a colour row's hit on the
/// catalog child carrying its census label key, while the row
/// marks itself through `ColorsAndGlassAnchors`. A swapped arm
/// opens the section and scrolls to the wrong row, and a missing
/// one marks nothing — both invisible to the index-side suites.
@Suite("Colors & glass row anchors")
@MainActor
struct ColorsAndGlassAnchorTests {
    /// Every colour row the section draws, the two role-group
    /// wells aside: they draw no `ColorsAndGlassRow` and land on
    /// their group's title through the group's own section.
    private var rows: [SettingKey] {
        SettingKey.allCases.filter {
            $0.isColourRow
                && $0 != ColorRole.accent.paint
                && $0 != ColorRole.secondAccent.paint
        }
    }

    @Test("each colour row anchors on its own label key")
    func rowsAnchorOnTheirLabelKey() {
        #expect(!rows.isEmpty)
        for key in rows {
            guard case .key(let label) = key.text.label else {
                Issue.record("\(key.id) has no label key")
                continue
            }
            #expect(
                ColorsAndGlassAnchors.control(for: key)?.key == label,
                Comment(rawValue: key.id)
            )
        }
    }

    /// The paint wells' census label is their group's title, so
    /// the join lands each on the group the section draws.
    @Test("each role group's well lands on its group's title")
    func wellsLandOnTheirGroup() {
        for role in ColorRole.allCases {
            guard case .key(let label) = role.paint.text.label else {
                Issue.record("\(role.paint.id) has no label key")
                continue
            }
            #expect(role.control.key == label)
        }
    }
}
