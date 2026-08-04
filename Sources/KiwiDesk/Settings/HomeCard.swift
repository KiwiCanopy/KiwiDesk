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
                    .foregroundStyle(.secondary)
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
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
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
            .foregroundStyle(.orange)
            .lineLimit(1)
    }

    private var cardShape: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        Color.primary.opacity(0.12)
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
