import KiwiDeskCore
import SwiftUI

/// One row in the search-result list (#678 turn 11, 4c): label
/// on top, dimmed breadcrumb beneath, the current value
/// right-aligned, and — only where committing would flip the
/// window into Power User mode — the pill, the one place search
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
    /// draft in memory. Called once per paint, on appear.
    let value: (SettingKey) -> String?
    /// Whether committing flips the mode (the pill).
    let switchesMode: Bool
    /// Same state-driven badge rule as the Home grid: which
    /// list renders the tile must not change it.
    let badged: Bool
    /// The spotlight dot's VoiceOver twin, empty when unbadged.
    let badgeValue: String
    let reveal: (SettingsSearchResult) -> Void

    var body: some View {
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
            if switchesMode { pill }
        }
        .contentShape(Rectangle())
        .onTapGesture { reveal(result) }
        // VoiceOver stops once per row and must hear the whole
        // context there, not split across unlabelled lines.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(axLabel)
        .accessibilityValue(badgeValue)
        // A tap gesture under a combined element is not reliably
        // reachable by VoiceOver's activate, and there is no
        // `Button` here to supply the trait, so both are
        // explicit — otherwise the reveal is mouse-only for AX
        // users.
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { reveal(result) }
    }

    /// The mode pill: the mode's own accent, on the same
    /// reduced-strength stroke channel the mode-gated container
    /// frames use — one visual system, and text stays neutral
    /// (the accent marks fills and frames, never words).
    private var pill: some View {
        // The SEGMENT's own key, reused on purpose: the pill
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
        case .palette:
            return L("search.place.palette", "Palette")
        case .appRule:
            return L("search.place.app_rule", "App rule")
        }
    }

    private var axLabel: String {
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
            label += ", " + shownValue
        }
        if switchesMode {
            label += ", " + L("mode.power_user", "Power User")
        }
        return label
    }
}
