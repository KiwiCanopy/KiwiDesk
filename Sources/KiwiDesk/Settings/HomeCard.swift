import KiwiDeskCore
import SwiftUI

/// Settings home grid navigation card (#678 turn 9).
struct HomeCard: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    let spotlighted: Bool
    let open: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                // Full-bleed plate band (#786).
                if let plate = HomeCardPlate.plate(
                    for: destination,
                    model: model
                ) {
                    plate
                }
                textBand
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
            // Border drawn above clip to preserve plate stroke (2026-08-09).
            .overlay(cardStroke)
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

    private var tall: Bool {
        HomeCardOrder.thisProfile.contains(destination)
    }

    private var textBand: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Mode reveal wash restricted to title row (#760).
            titleRow.modeRevealWash(modeGated)
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

    /// Whether destination is gated under Simple mode
    /// (`HomeCardOrderTests`, #760).
    private var modeGated: Bool {
        !HomeCardOrder.isOffered(
            destination,
            mode: .simple,
            displayCount: model.displays.count,
            editingStoredProfile: model.editingStoredProfile
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

    private func shoutBadge(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.warningInk)
            .lineLimit(1)
    }

    private var cardFill: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
            .fill(SettingsTheme.card)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: SettingsTheme.cardRadius)
            // Accent highlight on hover (owner ruled 2026-08-04, 2026-08-09).
            .strokeBorder(
                hovering
                    ? SettingsTheme.accent
                    : modeGated
                        ? SettingsTheme.accent.opacity(
                            SettingsTheme.modeGatedStrokeOpacity
                        )
                        : SettingsTheme.hairline,
                lineWidth: modeGated
                    ? SettingsTheme.containerStrokeModeGated
                    : SettingsTheme.containerStroke
            )
            .allowsHitTesting(false)
    }

    private var axValue: String {
        let base =
            if let shout {
                L(
                    "home.card.ax_value",
                    "%1$@, %2$@",
                    subtitle,
                    shout
                )
            } else {
                subtitle
            }
        // Power user mode narration (#760, ui-designer).
        guard modeGated else { return base }
        return L(
            "home.card.ax_value",
            "%1$@, %2$@",
            base,
            L("mode.power_user", "Power User")
        )
    }
}
