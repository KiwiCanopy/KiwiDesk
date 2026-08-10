import KiwiDeskCore
import SwiftUI

/// One row in the search-result list (#678 turn 11, 4c): label
/// on top, dimmed breadcrumb beneath, the current value
/// right-aligned, and — only where committing would flip the
/// window into Power User mode — the tag, the one place search
/// mentions the mode.
///
/// The value is ENRICHMENT: computed here, per rendered row,
/// inside the list's `LazyVStack` — so it runs for the rows on
/// screen after the list paints, never for the whole result set
/// on the match path. It reads the draft in memory through the
/// closure the shell supplies (`SettingsValueReadout` under it);
/// nothing here touches AX, the session or the filesystem.
struct SettingsSearchRow: View {
    let result: SettingsSearchResult
    /// Enrichment: the current value for a census key, from the
    /// draft in memory. Read once per body evaluation, and only
    /// while the row is instantiated — the list is lazy.
    let value: (SettingKey) -> String?
    /// Whether committing flips the mode (the tag).
    let switchesMode: Bool
    /// Same state-driven badge rule as the Home grid: which
    /// list renders the tile must not change it.
    let badged: Bool
    /// The spotlight dot's VoiceOver twin, empty when unbadged.
    let badgeValue: String
    let reveal: (SettingsSearchResult) -> Void

    var body: some View {
        // ONE read per body evaluation, shared by the visible
        // column and the AX sentence — the readout walks the
        // draft, so the row must not run it twice per repaint.
        let shownValue = shownValue
        HStack(spacing: 8) {
            SidebarTile(
                destination: result.destination,
                badged: badged
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(primary)
                    .lineLimit(1)
                if let breadcrumb {
                    Text(breadcrumb)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let shownValue {
                Text(shownValue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if switchesMode { modeTag }
        }
        .contentShape(Rectangle())
        .onTapGesture { reveal(result) }
        // VoiceOver stops once per row and must hear the whole
        // context there, not split across unlabelled lines.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(axLabel(shownValue))
        .accessibilityValue(badgeValue)
        // A tap gesture under a combined element is not reliably
        // reachable by VoiceOver's activate, and there is no
        // `Button` here to supply the trait, so both are
        // explicit — otherwise the reveal is mouse-only for AX
        // users.
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { reveal(result) }
    }

    /// The mode TAG — "tag", because the glossary rules
    /// exactly two senses of "pill" and this Settings-chrome
    /// capsule would collide with the save pill's. The mode's
    /// own accent, on the same reduced-strength stroke channel
    /// the mode-gated container frames use — one visual
    /// system, and text stays neutral (the accent marks fills
    /// and frames, never words).
    private var modeTag: some View {
        // The SEGMENT's own key, reused on purpose: the tag
        // and the mode segment must say the same word in every
        // locale, and sharing the key makes that structural
        // (localization audit 2026-08-10) — a second key would
        // put the match on every future translation round.
        Text(L("mode.power_user", "Power User"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().strokeBorder(
                    SettingsTheme.accent.opacity(
                        SettingsTheme.modeGatedStrokeOpacity
                    )
                )
            )
    }

    private var primary: String {
        switch result {
        case .destination(let d): return d.title
        case .setting(let row): return row.label
        case .place(let place): return place.name
        }
    }

    /// The setting rows' path joined for display; a place names
    /// its kind instead; a destination-title match has none.
    ///
    /// Elision is by *segment*, never `.truncationMode(.middle)`
    /// on the joined string — that would cut a word in half
    /// around a separator. The first segment decides what gets
    /// selected and the last is the nearest context, so the
    /// middle is the part that is safe to drop.
    private var breadcrumb: String? {
        switch result {
        case .destination:
            return nil
        case .setting(let row):
            let path = row.path
            guard let first = path.first, let last = path.last
            else { return nil }
            guard path.count > 2 else {
                return path.joined(separator: separator)
            }
            return first + separator + "…" + separator + last
        case .place(let place):
            return kindName(place.kind)
        }
    }

    private var shownValue: String? {
        guard case .setting(let row) = result,
            let key = row.key
        else { return nil }
        return value(key)
    }

    /// U+25B8, the glyph the cross-reference link titles already
    /// use — one separator for "inside", not a second invented
    /// here.
    private var separator: String { " ▸ " }

    private func kindName(
        _ kind: SettingsSearchPlace.Kind
    ) -> String {
        switch kind {
        case .space:
            return L("search.place.space", "Space")
        case .profile:
            return L("search.place.profile", "Profile")
        case .appRule:
            return L("search.place.app_rule", "App rule")
        }
    }

    /// The spoken sentence, composed by NESTED positional
    /// frames rather than `+`-stitched fragments: each locale
    /// owns its separators (ja/zh enumerate with 、/，) and may
    /// reorder either frame — the gui.md strings rule, applied
    /// to the AX-only surface too (review 2026-08-10).
    private func axLabel(_ shownValue: String?) -> String {
        var label = primary
        if let breadcrumb {
            label = L(
                "search.result_ax",
                "%1$@, in %2$@",
                primary,
                breadcrumb
            )
        }
        if let shownValue {
            label = L(
                "search.result_value_ax",
                "%1$@, %2$@",
                label,
                shownValue
            )
        }
        if switchesMode {
            // The frame carries "mode" itself. On screen the name
            // gets that context from the capsule it sits in;
            // VoiceOver has no capsule, so a bare name ends the
            // sentence on a dangling adjective in every language
            // this app ships — the mode name is adjectival in
            // all ten catalogs, never a standalone noun phrase.
            label = L(
                "search.result_mode_ax",
                "%1$@, %2$@ mode",
                label,
                L("mode.power_user", "Power User")
            )
        }
        return label
    }
}
