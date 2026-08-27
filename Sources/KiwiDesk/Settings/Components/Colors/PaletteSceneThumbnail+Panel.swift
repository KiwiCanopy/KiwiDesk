import KiwiDeskCore
import SwiftUI

/// The panel-scale palette scene (#793): one desktop holding every
/// role a still frame can honestly draw, so "do these colours work
/// together" is answerable without saving and looking at the real
/// desktop.
///
/// **Grown from the shelf tile rather than written beside it.**
/// The issue proposed composing this from `HomeCardBarsTile`; that
/// would have been wrong in a way worth recording, because the
/// mistake is attractive. The Home tiles speak
/// `HomeCardPlate.palette`'s fold — accent / ink / base — and
/// floor the accent against the plate for legibility. That
/// unification is right on Home and exactly wrong here: this is
/// the one page whose subject is per-role tinting, where a
/// `border.focused_color` the user has made illegible must READ
/// as illegible. So the renderer is the one that already speaks
/// raw palette paths, and it now serves three mounts — the shelf
/// tile, this panel, and the Colours & Animations panel, which gets
/// the richer scene for free.
///
/// Which roles are on the frame is `PaletteSceneRoles`, not this
/// file: a SwiftUI body cannot be read for coverage, and
/// `PaletteSceneRoleTests` holds the census total against
/// `ColorPaletteKeys.all`.
extension PaletteSceneThumbnail {
    /// Bars on their edges, the windows and their marks between,
    /// the drag pair beneath — the arrangement the real desktop
    /// has, so the scene reads as a place rather than a swatch
    /// list.
    var panelScene: some View {
        VStack(spacing: 7 * scale) {
            named(SettingsCatalog.bars.spaceBarCard) {
                spaceBarStrip
            }
            HStack(spacing: 7 * scale) {
                windowTile(
                    ring: color("border.focused_color"),
                    ringWidth: 2.5 * scale,
                    mark: color("sticky.color"),
                    // The ENGINE's own glyph, not a stand-in
                    // shape: `StickyStyle` owns which symbol a
                    // scope draws, and a capsule here would
                    // preview a mark the app never renders.
                    symbol: StickyStyle.symbolName(for: .global)
                )
                windowTile(
                    ring: color("border.unfocused_color"),
                    ringWidth: 1.5 * scale,
                    mark: color("floating.color"),
                    symbol: FloatingStyle.symbolName
                )
            }
            HStack(spacing: 7 * scale) {
                dragTile(
                    fill: color("drag.ghost.fill_color"),
                    border: color("drag.ghost.border_color"),
                    dashed: false
                )
                dragTile(
                    fill: color("drag.drop_zone.fill_color"),
                    border: color("drag.drop_zone.border_color"),
                    dashed: true
                )
            }
            named(SettingsCatalog.bars.appBarCard) {
                appBarStrip
            }
        }
    }

    /// A bar strip under its own name.
    ///
    /// The two bars are the only elements here drawn with no
    /// edge, no content and no context — everywhere else in the
    /// app they are told apart by WHERE they sit and what they
    /// hold, and this scene has neither. So on the one page
    /// whose subject is their colours, the reader could not say
    /// which strip was which without guessing from their own
    /// screen (owner, on device, 2026-08-16).
    ///
    /// The names come from the Bars page's own catalog
    /// declarations, so they are already translated and cannot
    /// drift from the cards that own those settings — no new
    /// keys for a labelling job.
    @ViewBuilder
    private func named<C: View>(
        _ control: SettingsControl,
        @ViewBuilder strip: () -> C
    ) -> some View {
        VStack(alignment: .leading, spacing: 3 * scale) {
            Text(control.text)
                .font(
                    .system(size: 7 * scale, weight: .semibold)
                )
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundStyle(SettingsTheme.ink3)
                .lineLimit(1)
                // Drawn, not spoken: the scene is one
                // accessibility element with its own summary,
                // and a legend read aloud as two stray nouns is
                // noise.
                .accessibilityHidden(true)
            strip()
        }
    }

    // MARK: - The two bars

    /// The Space Bar's three-step accent ladder — inactive,
    /// active, focused — plus the badge pair on the active item.
    /// The three steps are co-visible on purpose: they are what
    /// the colour-vision ruling is about, and separating them
    /// makes the question unanswerable.
    private var spaceBarStrip: some View {
        barPlate(fill: color("space_bar.fill_color")) {
            item(color("space_bar.item_color"))
            item(
                color("space_bar.active_item_color"),
                highlight: color("space_bar.highlight_color")
            )
            .overlay(alignment: .topTrailing) {
                badge(
                    color("space_bar.group_badge_color"),
                    ink: color("space_bar.group_badge_text_color")
                )
            }
            item(color("space_bar.focused_item_color"))
        }
    }

    /// The App Bar's own ladder. One step shorter — it has no
    /// `focused_item_color` — which the scene shows by drawing
    /// what is there rather than by leaving a gap.
    private var appBarStrip: some View {
        barPlate(fill: color("app_bar.fill_color")) {
            item(color("app_bar.item_color"))
            item(
                color("app_bar.active_item_color"),
                highlight: color("app_bar.highlight_color")
            )
            .overlay(alignment: .topTrailing) {
                badge(
                    color("app_bar.group_badge_color"),
                    ink: color("app_bar.group_badge_text_color")
                )
            }
            item(color("app_bar.item_color").opacity(0.55))
        }
    }

    private func barPlate<C: View>(
        fill: Color,
        @ViewBuilder items: () -> C
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(fill)
            .frame(height: 20 * scale)
            .overlay(
                HStack(spacing: 5 * scale) {
                    items()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 5 * scale)
            )
    }

    private func item(
        _ fill: Color,
        highlight: Color? = nil
    ) -> some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(fill)
            .frame(width: 18 * scale, height: 10 * scale)
            .overlay {
                if let highlight {
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .stroke(highlight, lineWidth: 1.5 * scale)
                }
            }
    }

    /// The count badge, drawn with its own text ink so the pair
    /// is judged as a pair — a badge whose number vanishes into
    /// its disc is the defect the two keys exist to prevent.
    private func badge(_ fill: Color, ink: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: 8 * scale, height: 8 * scale)
            .overlay(
                Circle()
                    .fill(ink)
                    .frame(width: 3 * scale, height: 3 * scale)
            )
            .offset(x: 3 * scale, y: -3 * scale)
    }

    // MARK: - Windows and drag visuals

    /// A window wearing its ring, with a state mark in the
    /// corner. The two tiles differ in ring WEIGHT as well as
    /// hue, matching what the app draws — so a palette whose
    /// unfocused ring competes with the focused one is visible
    /// as competition rather than hidden by the frame.
    private func windowTile(
        ring: Color,
        ringWidth: CGFloat,
        mark: Color,
        symbol: String?
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(SettingsTheme.hairline)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(ring, lineWidth: ringWidth)
            )
            .overlay(alignment: .topLeading) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(
                            .system(size: 9 * scale, weight: .bold)
                        )
                        .foregroundStyle(mark)
                        .padding(4 * scale)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30 * scale)
    }

    /// The ghost and its drop zone, side by side because #231
    /// says they are edited by comparison. The zone is dashed,
    /// which is how the app draws it — the difference between
    /// the two is what the twin columns exist to show.
    private func dragTile(
        fill: Color,
        border: Color,
        dashed: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 4 * scale)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * scale)
                    .stroke(
                        border,
                        style: StrokeStyle(
                            lineWidth: 2 * scale,
                            dash: dashed ? [3 * scale] : []
                        )
                    )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 22 * scale)
    }
}
