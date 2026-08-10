import KiwiDeskCore
import SwiftUI

/// The preview panel once the window is too narrow to give it a
/// column of its own (#678 turn 17a): the same
/// `SettingsDetailPanel`, floating over the content as a card
/// you can move out of the way or close.
///
/// **The same card in both narrow bands.** Between 900 and 1200
/// it opens with the screen; below 900 it waits behind "Show
/// preview". One mechanism, two defaults
/// (`SettingsWidthClass.floatsPreviewByDefault`) — so the thing
/// the user closes at 1100 and the thing they summon at 820 is
/// the same object, not two features.
///
/// The prototype's "auto-raises while you drag a slider" needs
/// no code: an overlay is already above every row, and the card
/// moves rather than the content moving under it.
struct SettingsFloatingPanel: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    /// The content area the card floats over — its own size and
    /// its travel both derive from this, so the card cannot be
    /// dragged out of the window.
    let bounds: CGSize
    let close: () -> Void
    /// Where the user has put the card, as an offset from its
    /// resting corner. Per-mount: a card dragged aside in Bars
    /// starts back in the corner in Shortcuts, which is where
    /// the eye looks for it.
    @State private var moved: CGSize = .zero
    @GestureState private var dragging: CGSize = .zero

    /// The card's ceiling. It floats over content the user is
    /// still reading, so it takes a fixed share rather than the
    /// full height a docked panel gets — and a fixed number is
    /// also what makes the travel clamp exact arithmetic rather
    /// than a guess about the panel's intrinsic height.
    static let maxHeight: CGFloat = 520

    /// The gutter between the card and the content's edges, at
    /// rest and as the travel limit.
    static let inset = SettingsMetrics.paneInset

    static func height(in bounds: CGSize) -> CGFloat {
        max(min(maxHeight, bounds.height - 2 * inset), 200)
    }

    /// The card's resting origin: the content area's trailing
    /// top corner, one gutter in.
    static func origin(in bounds: CGSize) -> CGPoint {
        CGPoint(
            x: bounds.width - SettingsTheme.panelWidth - inset,
            y: inset
        )
    }

    /// Clamps a proposed travel so the card always lands whole
    /// inside `bounds`. Pure and static so the responsive suite
    /// can assert the limits without mounting a window — the
    /// failure this prevents is a preview dragged off the
    /// bottom of a 720 pt window with no way to get it back.
    static func clamp(
        _ proposed: CGSize,
        in bounds: CGSize
    ) -> CGSize {
        let start = origin(in: bounds)
        let minX = -max(start.x - inset, 0)
        let maxY = max(
            bounds.height - height(in: bounds) - inset - start.y,
            0
        )
        return CGSize(
            width: min(max(proposed.width, minX), 0),
            height: min(max(proposed.height, 0), maxY)
        )
    }

    private var offset: CGSize {
        Self.clamp(
            CGSize(
                width: moved.width + dragging.width,
                height: moved.height + dragging.height
            ),
            in: bounds
        )
    }

    var body: some View {
        let start = Self.origin(in: bounds)
        return
            card
            .frame(
                width: SettingsTheme.panelWidth,
                height: Self.height(in: bounds)
            )
            .offset(
                x: start.x + offset.width,
                y: start.y + offset.height
            )
    }

    private var card: some View {
        VStack(spacing: 0) {
            grabBar
            SettingsDetailPanel(
                model: model,
                destination: destination
            )
        }
        .background(SettingsTheme.panel)
        .clipShape(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .strokeBorder(SettingsTheme.hairline)
        )
        // The 16b seam: the black shadow below is the card's
        // lift in light and dies on the dark page, where this
        // inset light line is the edge instead — by the token,
        // never a `colorScheme` branch.
        .overlay(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .strokeBorder(SettingsTheme.planeRing, lineWidth: 1)
        )
        // Without this the shadow halos every primitive inside
        // the card, the hairline ring casting its own shadow
        // inward (#758's lesson, re-learned on the search
        // panel).
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    /// The card's handle. The drag gesture lives HERE, not on
    /// the card: a gesture over the whole card would compete
    /// with the diff rows' clicks and with any control the
    /// preview grows later, and losing a click to the container
    /// is the kind of bug nobody reports as a drag bug.
    private var grabBar: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(SettingsTheme.ink3.opacity(0.5))
                .frame(width: 34, height: 4)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SettingsTheme.ink3)
            }
            .buttonStyle(.plain)
            .iconButtonAffordance(
                L("panel.hide_preview", "Hide preview")
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragging) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    moved = Self.clamp(
                        CGSize(
                            width: moved.width
                                + value.translation.width,
                            height: moved.height
                                + value.translation.height
                        ),
                        in: bounds
                    )
                }
        )
        .accessibilityLabel(
            L("panel.move_preview", "Move preview")
        )
    }
}
