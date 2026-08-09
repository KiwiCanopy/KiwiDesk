import KiwiDeskCore
import SwiftUI

/// The scene tiles of the Home card plates (#786): Gaps &
/// Borders and Bars. Split from `HomeCardPlate.swift` at the
/// file-size target — Monitors and Behaviour sit in
/// `HomeCardPlate+Desk.swift` — and the container, palette and
/// dispatch stay there.

/// The editor's own four-window picture on the plate (owner,
/// 2026-08-09 — over the two-pane cut): a 2×2 grid whose
/// spacing IS the answer — the seams read the inner gaps, the
/// insets to the plate edge the outer gaps, each through
/// `GapPreviewScale.mini`, the same maths the Gaps editor
/// teaches with — and the borders highlighted: the focused
/// window ringed in the real border colour at
/// `FocusBorderPreview`'s 1–20 → 1–7 remap, its neighbours
/// ringed only while unfocused borders are on. Deliberately not
/// a layout preview, like the diagram it echoes.
struct HomeCardGapsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    var body: some View {
        let outer = settings.gapsGlobal.outer
        let inner = settings.gapsGlobal.inner
        // The four windows live inside an implied 16:10 SCREEN
        // centred in the plate, not stretched to its edges
        // (owner, 2026-08-09) — the outer-gap readouts inset
        // from the screen outline, air on all sides beyond it.
        // No fill behind the panes: the owner tried an accent
        // gap-wash on device and ruled the empty interior back
        // in (2026-08-09) — the seams and margins read as
        // spacing on the bare plate, matching the Layout
        // Defaults band's ground, and no window carries a
        // highlight fill either; the border rings are the only
        // accent this tile speaks.
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    palette?.frame
                        ?? Color.secondary.opacity(0.3)
                )
            VStack(spacing: mini(inner.vertical)) {
                HStack(spacing: mini(inner.horizontal)) {
                    pane(focused: true)
                    pane(focused: false)
                }
                HStack(spacing: mini(inner.horizontal)) {
                    pane(focused: false)
                    pane(focused: false)
                }
            }
            .padding(.top, 2 + mini(outer.top))
            .padding(.bottom, 2 + mini(outer.bottom))
            .padding(.leading, 2 + mini(outer.left))
            .padding(.trailing, 2 + mini(outer.right))
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        // Vertical air beyond the aspect fit: height-bound
        // plates left the screen outline flush with the plate
        // padding; 6 lands the margins level with the Layout
        // Defaults band's (owner, 2026-08-09, third pass).
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mini(_ real: CGFloat) -> CGFloat {
        GapPreviewScale.mini(real)
    }

    /// A window pane: opaque plate base under a quiet ghost
    /// fill, ringed at the remapped real width — the focused
    /// window always, its neighbours only while unfocused
    /// borders are on. The ring speaks the PALETTE accent, not
    /// `border.focused_color` (owner ruled unify, 2026-08-09):
    /// side by side with the other tiles' accent marks, two
    /// greens on one Home read as drift, so the width and the
    /// presence stay the real readouts and the colour joins the
    /// plate family's one voice.
    @ViewBuilder
    private func pane(focused: Bool) -> some View {
        let border = settings.borderStyle
        let ringed =
            border.enabled
            && (focused || border.unfocusedEnabled)
        RoundedRectangle(cornerRadius: 4)
            .fill(palette?.base ?? SettingsTheme.previewPlate)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        palette?.ghostFill
                            ?? Color.secondary.opacity(0.15)
                    )
            )
            .overlay {
                if ringed {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            focused
                                ? palette?.accent
                                    ?? SettingsTheme.accent
                                : palette?.ghostStroke
                                    ?? Color.secondary
                                    .opacity(0.5),
                            lineWidth: strokeWidth
                        )
                }
            }
    }

    /// The one shared remap (`BorderPreviewScale`), into a band
    /// proportional to this tile's third-size panes — the same
    /// real width reads the same weight here and on the
    /// editor's mock (owner scale round + review, 2026-08-09).
    private var strokeWidth: CGFloat {
        BorderPreviewScale.width(
            settings.borderStyle.clampedWidth,
            to: 1...3
        )
    }
}

/// The Bars picture: each bar the desktop actually shows, as a
/// plate on its own edge in its own fill, the desktop well
/// between them. The edge-most bar on a shared edge is the
/// Space Bar, matching `SpaceBarPreviewStrip`'s coexistence
/// order. Every plate wears the well's hairline — the DEFAULT
/// fill composites into the plate, the 13b invisible class
/// (ui-designer, 2026-08-09).
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    @Environment(\.schematicPalette) private var palette

    /// The App Bar is shown per LAYOUT; whether any layout
    /// shows one is `BarsGates`' own block predicate, consulted
    /// rather than re-derived (the resolver rule) — a card that
    /// drew the bar anyway would assert a bar the desktop never
    /// shows.
    private var appBarShown: Bool {
        BarsGates(settings: settings).anyBarShown
    }

    var body: some View {
        HStack(spacing: 3) {
            columnBars(.left)
            VStack(spacing: 3) {
                rowBars(.top)
                well
                rowBars(.bottom)
            }
            columnBars(.right)
        }
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? Color.secondary.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? Color.secondary.opacity(0.3)
                    )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The bars on a horizontal edge, edge-most first for
    /// `.top` and window-most first for `.bottom`, so both hug
    /// the screen edge.
    @ViewBuilder
    private func rowBars(_ edge: AppBarEdge) -> some View {
        if edge == .top {
            spaceStrip(on: edge)
            appStrip(on: edge)
        } else {
            appStrip(on: edge)
            spaceStrip(on: edge)
        }
    }

    @ViewBuilder
    private func columnBars(_ edge: AppBarEdge) -> some View {
        if edge == .left {
            spaceStrip(on: edge, vertical: true)
            appStrip(on: edge, vertical: true)
        } else {
            appStrip(on: edge, vertical: true)
            spaceStrip(on: edge, vertical: true)
        }
    }

    @ViewBuilder
    private func spaceStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.spaceBarStyle
        if style.enabled, style.edge == edge {
            barPlate(
                fill: style.fillColor,
                items: [
                    (style.activeItemColor, CGFloat(12)),
                    (style.itemColor, 12),
                    (style.itemColor, 12),
                ],
                vertical: vertical
            )
        }
    }

    @ViewBuilder
    private func appStrip(
        on edge: AppBarEdge,
        vertical: Bool = false
    ) -> some View {
        let style = settings.appBarStyle
        if appBarShown, style.edge == edge {
            barPlate(
                fill: style.fillColor,
                items: [
                    (style.activeItemColor, CGFloat(20)),
                    (style.itemColor, 20),
                ],
                vertical: vertical
            )
        }
    }

    private func barPlate(
        fill: String,
        items: [(String, CGFloat)],
        vertical: Bool
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(kiwiHex: fill))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.plateInk
                            .opacity(0.3)
                    )
            )
            .frame(
                width: vertical ? 16 : nil,
                height: vertical ? nil : 16
            )
            .overlay(
                stack(vertical: vertical) {
                    ForEach(
                        Array(items.enumerated()),
                        id: \.offset
                    ) { _, item in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(kiwiHex: item.0))
                            .frame(
                                width: vertical ? 9 : item.1,
                                height: vertical ? item.1 : 9
                            )
                    }
                }
                .padding(vertical ? .vertical : .horizontal, 5)
            )
    }

    @ViewBuilder
    private func stack(
        vertical: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if vertical {
            VStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 4) {
                content()
                Spacer(minLength: 0)
            }
        }
    }
}
