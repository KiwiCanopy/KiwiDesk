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
            VStack(alignment: .leading, spacing: 0) {
                // The desktop plate rides ABOVE the title and
                // outside the reveal wash (#786): full-bleed,
                // clipped through the card's own corners, so
                // the card border is the picture's visible
                // edge (4g).
                if let plate = HomeCardPlate.plate(
                    for: destination,
                    model: model
                ) {
                    plate
                }
                textBand
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Two deliberate heights (#786): the profile group
            // holds the plate band — Behaviour plateless but
            // tall, so its group still reads as one row grid —
            // and the whole-app cards sit shorter.
            .frame(
                height: tall
                    ? SettingsTheme.cardHeight
                    : SettingsTheme.cardHeightCompact
            )
            .background(cardShape)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
            )
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

    /// The one group partition, read where the group order
    /// already lives — never a second hand-kept list.
    private var tall: Bool {
        HomeCardOrder.thisProfile.contains(destination)
    }

    private var textBand: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Wash on the title band alone (#760): tinting
            // the whole card would run the accent through
            // the live preview, briefly misrepresenting the
            // very colours it renders.
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

    /// Whether this card would leave the page in Simple — THE
    /// offer predicate at `.simple`, never a hand-negated copy
    /// (the one-predicate rule, `HomeCardOrderTests`): the
    /// Monitors promotion means the same card is mode-gated on a
    /// laptop and Simple content on a desk, and only the real
    /// predicate keeps the border stating the same fact as
    /// presence (#760).
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
                // The mode-gated frame speaks the mode's own
                // colour — the accent at reduced strength, so
                // the connection to the active Power User
                // segment is legible (owner, 2026-08-09: a
                // darker grey read as "different" but not
                // "which") while hover keeps the full-strength
                // accent as its own register on the same edge.
                // Weight still steps too, so hue never carries
                // alone.
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
            )
    }

    private var axValue: String {
        // One positional frame, not a hard-coded ", " — the
        // joiner between two localized statements is the
        // translator's (CJK wants 、/，).
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
        // Sighted users read the mode fact off the frame's
        // accent and the header segment; VoiceOver hears it
        // here or nowhere (#760, ui-designer). Reuses the
        // segment's own label key, so the spoken word and the
        // switch cannot drift apart.
        guard modeGated else { return base }
        return L(
            "home.card.ax_value",
            "%1$@, %2$@",
            base,
            L("mode.power_user", "Power User")
        )
    }
}
