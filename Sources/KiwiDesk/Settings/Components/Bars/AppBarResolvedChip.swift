import KiwiDeskCore
import SwiftUI

/// A compact resolved-state chip for a layout's App Bar override
/// disclosure (#125 Phase 2): swatches of the *resolved* style
/// (global overlaid with this layout's overrides via
/// `LayoutAppBar.resolved(with:)`) plus a count of how many
/// fields diverge. Deliberately NOT a second mock strip — the
/// disclosure is kept lazy on purpose, so this answers "does
/// this layout differ, and how" at near-zero mount cost. The
/// override count is discovered by reflection so a new
/// `LayoutAppBar` field can't silently escape it.
struct AppBarResolvedStateChip: View {
    let bar: LayoutAppBar
    let global: AppBarStyle

    var body: some View {
        let resolved = bar.resolved(with: global)
        HStack(spacing: 6) {
            swatch(resolved.fillColor)
            swatch(resolved.itemColor)
            swatch(resolved.highlightColor)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement()
        .accessibilityLabel(summary)
    }

    private func swatch(_ hex: String) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color(kiwiHex: hex))
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.secondary.opacity(0.4))
            )
    }

    private var summary: String {
        let n = overrideCount
        if n == 0 {
            return L(
                "app_bar.resolved.inherits",
                "Inherits the global bar."
            )
        }
        return L(
            "app_bar.resolved.overrides",
            "%1$d field(s) override the global bar.",
            n
        )
    }

    /// Non-nil optional properties = the overridden fields. The
    /// always-present `enabled: Bool` is not an optional, so it
    /// is skipped; every new optional override field is counted
    /// automatically (no hand-kept list to forget).
    private var overrideCount: Int {
        Mirror(reflecting: bar).children.reduce(0) { total, child in
            let value = Mirror(reflecting: child.value)
            let isSetOptional =
                value.displayStyle == .optional
                && value.children.first != nil
            return total + (isSetOptional ? 1 : 0)
        }
    }
}
