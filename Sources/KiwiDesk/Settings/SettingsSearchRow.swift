import KiwiDeskCore
import SwiftUI

/// One row in search result list (#678 turn 11, 4c, `SettingsValueReadout`).
struct SettingsSearchRow: View {
    let result: SettingsSearchResult
    /// Enrichment: current setting value evaluated from in-memory draft.
    let value: (SettingKey) -> String?
    /// Whether committing flips active settings mode.
    let switchesMode: Bool
    /// Badge indicator status.
    let badged: Bool
    /// Accessibility value for badge indicator.
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
                        .foregroundStyle(SettingsTheme.ink3)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let shownValue {
                Text(shownValue)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink3)
                    .lineLimit(1)
            }
            if switchesMode { modeTag }
        }
        .contentShape(Rectangle())
        .onTapGesture { reveal(result) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(axLabel(shownValue))
        .accessibilityValue(badgeValue)
        // A tap gesture under a combined element is not reliably
        // reachable by VoiceOver's activate, and no `Button`
        // supplies the trait — both explicit, or the reveal is
        // mouse-only for AX users.
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { reveal(result) }
    }

    /// Mode tag capsule indicator (localization audit 2026-08-10).
    private var modeTag: some View {
        Text(L("mode.power_user", "Power User"))
            .font(.caption2)
            .foregroundStyle(SettingsTheme.ink3)
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

    /// Joined breadcrumb path segments. Elision is by SEGMENT,
    /// never `.truncationMode(.middle)` on the joined string: the
    /// first segment decides what gets selected and the last is
    /// the nearest context, so the middle is what is safe to
    /// drop.
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

    /// Spoken accessibility label (`gui.md`, review 2026-08-10).
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
