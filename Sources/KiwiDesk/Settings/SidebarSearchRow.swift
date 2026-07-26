import KiwiDeskCore
import SwiftUI

/// One row in the flat search-result list (#277).
///
/// The matched text leads and the path above it becomes a quiet
/// breadcrumb caption (ui-designer 2026-07-27) — the user typed a
/// word, so the row's biggest text is that word, not the
/// destination they could already infer. A destination-title
/// match has no path and so keeps the tier-1 look exactly.
struct SidebarSearchRow: View {
    let result: SidebarSearchResult
    /// Same state-driven badge rule as the grouped rows: which
    /// list renders the tile must not change it (review
    /// 2026-07-19).
    let badged: Bool
    /// The spotlight dot's VoiceOver twin, empty when unbadged.
    let badgeValue: String
    let reveal: (SettingsAnchor) -> Void

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.primary)
                    .lineLimit(1)
                if let breadcrumb {
                    Text(breadcrumb)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } icon: {
            SidebarTile(
                destination: result.destination,
                badged: badged
            )
        }
        .tag(result.destination)
        // Selection alone cannot carry the anchor, so the tap
        // goes through `reveal`, which sets the destination too —
        // the `.tag` above keeps the highlight and arrow-key
        // navigation working (a keyboard move navigates without
        // scrolling, which is the honest behavior: nothing was
        // picked).
        .contentShape(Rectangle())
        .onTapGesture { reveal(result.anchor) }
        // VoiceOver stops once per row and must hear the whole
        // context there, not split across two unlabelled lines —
        // the same argument the Monitors fingerprint rows make.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(axLabel)
        .accessibilityValue(badgeValue)
    }

    /// The path joined for display, or nil for a
    /// destination-title match.
    ///
    /// Elision is by *segment*, never `.truncationMode(.middle)`
    /// on the joined string — that would cut a word in half
    /// around a separator. The first segment decides what gets
    /// selected and the last is the nearest context, so the
    /// middle is the part that is safe to drop.
    private var breadcrumb: String? {
        let path = result.path
        guard let first = path.first, let last = path.last
        else { return nil }
        guard path.count > 2 else {
            return path.joined(separator: separator)
        }
        return first + separator + "…" + separator + last
    }

    /// U+25B8, the glyph the cross-reference link titles already
    /// use ("Layout Defaults ▸ Scrolling") — one separator for
    /// "inside", not a second invented here.
    private var separator: String { " ▸ " }

    private var axLabel: String {
        guard !result.path.isEmpty else { return result.primary }
        return L(
            "sidebar.search.result_ax",
            "%1$@, in %2$@",
            result.primary,
            result.path.joined(separator: ", ")
        )
    }
}
