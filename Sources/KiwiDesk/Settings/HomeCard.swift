import KiwiDeskCore
import SwiftUI

/// Settings home grid navigation card (#678 turn 9).
struct HomeCard: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    let spotlighted: Bool
    let open: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.shellSpace) private var shellSpace

    var body: some View {
        Button(action: open) {
            let plate = HomeCardPlate.plate(
                for: destination,
                model: model
            )
            VStack(alignment: .leading, spacing: 0) {
                // Full-bleed plate band (#786).
                if let plate { plate }
                textBand(plated: plate != nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(
                height: tall
                    ? SettingsTheme.cardHeight
                    : SettingsTheme.cardHeightCompact
            )
            .background(cardFill)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
            )
            // Border ABOVE the clip, never in the background:
            // the plate is opaque and full-bleed, so a background
            // stroke is painted over — which silenced the rest
            // hairline and the #760 frame on every plated card
            // (ui-designer blocker, 2026-08-09).
            .overlay(cardStroke)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
            )
            // The box its page grows out of, outside the card's clip
            // so the morph is not cut to the card (#2737 ruling 13).
            .background(
                RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
                    .fill(SettingsTheme.card)
                    .shellMatched(
                        ShellMotion.boxID(destination),
                        in: shellSpace
                    )
            )
            // `HoverChip`'s own duration, so the two hover
            // idioms in the tree move at one speed.
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(destination.title)
        .accessibilityValue(axValue)
    }

    private var tall: Bool {
        HomeCardOrder.thisProfile.contains(destination)
    }

    /// Only a plated card pins its subtitle to the bottom; a
    /// bare card keeps an empty preview row, sitting as an
    /// empty-preview card does (#1610).
    private func textBand(plated: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            titleRow
            if let preview = HomeCardPreview.preview(
                for: destination,
                model: model
            ) {
                preview
            } else if plated {
                Spacer(minLength: 0)
            } else {
                Color.clear.frame(height: 0)
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
        .padding(.horizontal, 14)
        .padding(.top, 11)
        .padding(.bottom, 12)
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
                .shellMatched(
                    ShellMotion.titleID(destination),
                    in: shellSpace
                )
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

    /// The pointer's channel. On a plated card the lift is the
    /// text band alone: the plate is opaque and full-bleed
    /// (#1173).
    private var cardFill: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
            .fill(
                hovering
                    ? SettingsTheme.cardHover
                    : SettingsTheme.card
            )
    }

    /// The card's edge; the pointer lifts the fill, never this
    /// (#1173).
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
            .strokeBorder(
                SettingsTheme.hairline,
                lineWidth: SettingsTheme.containerStroke
            )
            .allowsHitTesting(false)
    }

    /// One positional frame, never a hard-coded ", ": the joiner
    /// between two localized statements is the translator's (CJK
    /// wants 、/，).
    private var axValue: String {
        guard let shout else { return subtitle }
        return L(
            "home.card.ax_value",
            "%1$@, %2$@",
            subtitle,
            shout
        )
    }
}
