import KiwiDeskCore
import SwiftUI

/// The data-row half of a Home card's picture (#678 turn 9,
/// re-cut in #786): the whole-app cards' previews, drawn only
/// from the real draft — a card is a mirror, not an
/// illustration. The profile-group cards moved their pictures
/// to the desktop plate (`HomeCardPlate`); what stays here are
/// rows of data — key caps, profile chips, app icons, the
/// version — that belong beside the title, not on a desktop.
@MainActor
enum HomeCardPreview {
    /// The card's data row, or nil for the cards with none —
    /// ONE switch, so "has a preview" and "which preview"
    /// cannot drift apart (review 2026-08-04: the earlier
    /// `hasPreview` twin was a second hand-kept copy of this
    /// partition). `AnyView` is the price of the optional; a
    /// card body mounts it at most once.
    static func preview(
        for destination: SettingsDestination,
        model: SettingsModel
    ) -> AnyView? {
        switch destination {
        case .shortcuts:
            return AnyView(keyCaps(model))
        case .profiles:
            return AnyView(profileChips(model))
        case .appRules:
            return AnyView(ruleIcons(model))
        case .general:
            return AnyView(versionLine)
        case .spaces, .bars, .layoutDefaults, .monitors,
            .gapsAndBorders, .colors, .advancedColors,
            .behavior:
            // The profile group draws on the plate or not at
            // all (`HomeCardPlate.plate` is that partition's
            // one switch).
            return nil
        }
    }

    // MARK: - Pieces

    /// How many chips the row draws before the "+N" takes a slot.
    static let chipCap = 4

    /// Capsule chips of the real profile names, the default one
    /// inverted — the answer "which one wins" read without the
    /// subtitle — capped with a "+N" chip that is a label, not
    /// an affordance.
    ///
    /// **In the LIST's order, and capped by the shared grammar.**
    /// Two defects lived here until #859, and both were #789's own
    /// arguments surviving on a second surface:
    ///
    /// - It sliced raw `profileSummaries`, which is
    ///   `allProfiles()`'s **unordered** read
    ///   (`ProfilesFamilyRows.profiles` says so itself), while
    ///   every other consumer takes `orderedProfiles` — the
    ///   match-first sort. So the card could hide the
    ///   live-matching profile behind a "+N" and show three that
    ///   match nothing, under a comment claiming it answered
    ///   "which one wins".
    /// - It computed `count - cap` by hand, so five profiles drew
    ///   four chips and "+1" — the one thing the shared grammar
    ///   forbids (`docs/ui-patterns.md` ▸ "+N"): the marker takes
    ///   a slot of its own precisely so it never claims to hide
    ///   exactly one. Routing it through `OverflowSplit` CHANGES
    ///   what this draws rather than preserving it, which is why
    ///   it waited for a branch that books an eye-confirm.
    ///
    /// The two sibling non-adopters in this tree — `ruleIcons`
    /// below and `HomeCardSpacesTile` — are deliberately NOT swept
    /// here: each is a different card owing its own eye-confirm,
    /// and neither carries the ordering half. `OverflowSplit`'s own
    /// doc comment states the obligation rather than a census of
    /// who has not met it yet, and that is the form it stays in.
    private static func profileChips(
        _ model: SettingsModel
    ) -> some View {
        let summaries = ProfilesFamilyRows.orderedProfiles(
            model.profileSummaries
        )
        let visible = OverflowSplit.shown(
            of: summaries.count,
            fitting: chipCap,
            withMarker: chipCap - 1
        )
        let shown = Array(summaries.prefix(visible))
        let overflow = max(summaries.count - shown.count, 0)
        return HStack(spacing: 4) {
            ForEach(shown, id: \.name) { summary in
                Text(summary.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(
                        summary.isDefault
                            ? SettingsTheme.card
                            : SettingsTheme.ink
                    )
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                summary.isDefault
                                    ? SettingsTheme.ink
                                    : SettingsTheme.sunken
                            )
                    )
            }
            if overflow > 0 {
                overflowChip(overflow)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func overflowChip(_ count: Int) -> some View {
        Text("+\(count)")
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .strokeBorder(SettingsTheme.hairline)
            )
    }

    /// The ruled apps' real icons in small wells — through the
    /// memoized cache the App Rules rows warm, never a raw
    /// `NSWorkspace` read per card — with a "+N" well for the
    /// rest. Union of both rule kinds, the same pair the
    /// subtitle counts.
    private static func ruleIcons(
        _ model: SettingsModel
    ) -> some View {
        // Float rules are colon syntax ("app:Title") — the app
        // segment comes from the ONE parse the area renders
        // with (`FloatFacet.appSegment`), or a titled rule
        // draws a generic well and a doubly-ruled app draws
        // twice (code review, 2026-08-09).
        let ids = Set(model.config.appRules.keys)
            .union(
                model.config.floatRules.map(
                    FloatFacet.appSegment(of:)
                )
            )
            .sorted()
        let shown = Array(ids.prefix(5))
        let overflow = ids.count - shown.count
        return HStack(spacing: 4) {
            ForEach(shown, id: \.self) { id in
                well {
                    Image(
                        nsImage: AppIconCache.shared.icon(
                            forBundleID: id
                        )
                    )
                    .resizable()
                    .frame(width: 16, height: 16)
                }
            }
            if overflow > 0 {
                well {
                    Text("+\(overflow)")
                        .font(.system(size: 9))
                        .foregroundStyle(SettingsTheme.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func well(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(SettingsTheme.sunken)
            .frame(width: 22, height: 22)
            .overlay(content())
    }

    /// The version the About row states, through the one shared
    /// derivation, so the card can never disagree with the area
    /// it opens.
    private static var versionLine: some View {
        Text(
            L(
                "home.card.general.version",
                "v%1$@",
                KiwiDeskVersion.displayString
            )
        )
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The first few default-layer combos as native key caps,
    /// through the same glyph pipeline the recorder displays
    /// with — the prototype's cut: small semibold mono on the
    /// sunken chip fill, no stroke ring (owner, 2026-08-09:
    /// "softer, smaller, sleeker").
    @ViewBuilder
    private static func keyCaps(
        _ model: SettingsModel
    ) -> some View {
        let combos =
            model.config.layers
            .first { $0.isDefault }?
            .bindings.prefix(4)
            .map(\.combo) ?? []
        HStack(spacing: 4) {
            ForEach(combos, id: \.self) { combo in
                Text(capText(combo))
                    .font(
                        .system(
                            size: 10.5,
                            weight: .semibold,
                            design: .monospaced
                        )
                    )
                    .foregroundStyle(SettingsTheme.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(SettingsTheme.sunken)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The recorder's own combo rendering (#23): glyphs mapped
    /// through the active keyboard layout, raw string on a
    /// parse failure.
    private static func capText(_ combo: String) -> String {
        guard let parsed = KeyCombo.parse(combo) else {
            return combo
        }
        return ComboSymbols.render(
            parsed,
            layoutChar: LayoutKeyGlyph.char
        )
    }
}
