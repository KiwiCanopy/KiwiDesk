import KiwiDeskCore
import SwiftUI

/// One Home card (#678 turn 9): the destination's tile and
/// title, a small live preview where one exists, and the
/// current-value subtitle. A plain `Button`, so focus ring and
/// Return/Space activation come native; VoiceOver reads it as
/// one element whose value is the answer the card carries.
struct HomeCard: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    /// The Profiles spotlight dot — state-driven, same rule as
    /// the old sidebar tile.
    let spotlighted: Bool
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                titleRow
                if let preview = HomeCardPreview.preview(
                    for: destination,
                    model: model
                ) {
                    preview
                } else {
                    Spacer(minLength: 0)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 148)
            .background(cardShape)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(destination.title)
        .accessibilityValue(axValue)
    }

    private var subtitle: String {
        HomeCardContent.subtitle(
            for: destination,
            model: model
        )
    }

    private var shout: String? {
        HomeCardContent.conflictShout(
            for: destination,
            model: model
        )
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            SidebarTile(
                destination: destination,
                badged: spotlighted
            )
            Text(destination.title)
                .font(.headline)
                .foregroundStyle(SettingsTheme.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let shout {
                shoutBadge(shout)
            }
        }
    }

    /// Glyph + text, warning ink — never hue alone (the
    /// red-on-green protanopia lesson).
    private func shoutBadge(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.warningInk)
            .lineLimit(1)
    }

    /// Flat: fill plus a hairline, no shadow — the prototype's
    /// cards separate by border, which is also what makes them
    /// survive the dark appearance, where surfaces sit within ten
    /// points of each other and a shadow reads as dirt.
    ///
    /// Hover swaps the hairline for the accent (owner ruled,
    /// 2026-08-04). It is the border and only the border, so it
    /// composes with — rather than competes against — the native
    /// focus ring a keyboard user gets from the plain `Button`.
    private var cardShape: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
            .fill(SettingsTheme.card)
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .strokeBorder(
                    hovering
                        ? SettingsTheme.accent
                        : SettingsTheme.hairline
                )
            )
    }

    private var axValue: String {
        guard let shout else { return subtitle }
        // One positional frame, not a hard-coded ", " — the
        // joiner between two localized statements is the
        // translator's (CJK wants 、/，).
        return L(
            "home.card.ax_value",
            "%1$@, %2$@",
            subtitle,
            shout
        )
    }
}
