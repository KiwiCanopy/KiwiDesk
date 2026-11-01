import KiwiDeskCore
import SwiftUI

/// Desktop preview scene for the Bars panel (#678, `HomeCardBarsTile`).
struct BarsPanelPreview: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if settings.bothBarsCanShow {
                framed(showsAppBar: true, caption: hostNames)
                framed(
                    showsAppBar: false,
                    caption: L(
                        "bars.preview.other_layouts",
                        "Other layouts"
                    )
                )
            } else {
                // An App Bar alone shows only in its layouts, so
                // the one frame says which.
                framed(
                    showsAppBar: true,
                    caption: settings.anyAppBarCanShow
                        ? hostNames : nil
                )
            }
            Text(
                L(
                    "panel.caption.draft",
                    "Shows your draft, not the saved profile."
                )
            )
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink3)
        }
    }

    private var settings: TilingSettings { model.config.settings }

    /// The layouts whose App Bar joins the Space Bar, in the
    /// order Core lists its hosts — the frame they share.
    private var hostNames: String {
        LayoutMode.allCases
            .filter {
                settings.appBarVisibility(in: $0).map(\.showsUnprompted)
                    == true
            }
            .map(\.displayName)
            .joined(separator: " · ")
    }

    /// One desktop frame. While both bars can show, the panel
    /// draws two — the Space Bar alone, and the two sharing the
    /// shelf — since no layout shows both pictures at once.
    private func framed(
        showsAppBar: Bool,
        caption: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Self.tile(
                settings,
                config: model.config,
                pocketStands: model.pocketStandsAtRest,
                showsAppBar: showsAppBar
            )
            .padding(Self.framePad)
            .frame(height: caption == nil ? 210 : Self.shortFrame)
            .frame(maxWidth: .infinity)
            .deskPlate(settings, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
            if let caption {
                // Hidden with the frame it names: a caption read
                // over a picture VoiceOver does not see is a
                // sentence about nothing.
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink2)
                    .accessibilityHidden(true)
            }
        }
    }

    /// What a 1.8× panel frame draws: three Spaces at most and two
    /// mock App Bar items, the most its shortest strip holds whole,
    /// Boxed included (owner, #2781).
    static let spaces = 3
    static let mockApps = 2
    /// The shortest panel frame's height and every frame's pad,
    /// which `MockAppItemLengthTests` derives the strip from.
    static let shortFrame: CGFloat = 150
    static let framePad: CGFloat = 12

    /// The 1.8× shelf picture a panel frame draws — the Bars panel
    /// and the Colors & glass scene alike, so one place holds what
    /// the frame fits.
    static func tile(
        _ settings: TilingSettings,
        config: GuiConfig,
        pocketStands: Bool,
        showsAppBar: Bool = true
    ) -> HomeCardBarsTile {
        HomeCardBarsTile(
            settings: settings,
            pocketStands: pocketStands,
            spaceCount: min(config.spaces.count, spaces),
            scale: 1.8,
            spaceLabels: spaceLabels(of: config),
            showsAppBar: showsAppBar,
            mockApps: mockApps
        )
    }

    /// Each Space's label as the bar draws it — Core's own
    /// ladder, never a reading of the preview's own (#1538,
    /// #1535). A layout label reads the DRAFT's modes, so a
    /// temporary layout the bar shows is not drawn (#1179).
    static func spaceLabels(of config: GuiConfig) -> [SpaceGlyph] {
        let modes = config.modes(for: config.spaces)
        let label = config.settings.spaceBarStyle.itemLabel
        return config.spaces.compactMap { id in
            modes[id].map { mode in
                KiwiCore.spaceBarLabel(
                    identifier: KiwiCore.spaceIdentifier(
                        id: id,
                        icon: config.settings.spaceIcons[id]
                    ),
                    mode: mode,
                    label: label
                )
            }
        }
    }
}
