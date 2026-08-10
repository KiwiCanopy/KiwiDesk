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

    /// The panel is built HERE and handed to `MovableCard` as a
    /// stored child — which is the whole reason that type
    /// exists. See its docstring: the drag must not re-enter
    /// this body.
    var body: some View {
        MovableCard(bounds: bounds, close: close) {
            SettingsDetailPanel(
                model: model,
                destination: destination
            )
        }
    }
}

/// The card chrome and the drag, with the preview as a STORED
/// child (#678 turn 17a).
///
/// The split is a performance decision, and it is load-bearing
/// rather than tidiness: a drag emits a gesture update per
/// frame, and every update invalidates the body of whichever
/// view declares the gesture state. With the panel built inside
/// that body, each frame re-ran `SettingsDetailPanel` — which
/// diffs the whole draft (`SettingsDiffRowSource.rows`) and
/// redraws a live schematic — and the card visibly stuttered
/// under the pointer (owner, on device). Declaring the gesture
/// one level down, over a child that was already built, leaves
/// the drag re-rendering the chrome and translating a subtree
/// whose value never changes.
///
/// So: never move the `@GestureState` back up into a view that
/// builds the preview, and never build the preview inline here.
private struct MovableCard<Content: View>: View {
    let bounds: CGSize
    let close: () -> Void
    /// Where the user has put the card, as an offset from its
    /// resting corner. Per-mount: a card dragged aside in Bars
    /// starts back in the corner in Shortcuts, which is where
    /// the eye looks for it.
    @State private var moved: CGSize = .zero
    @GestureState private var dragging: CGSize = .zero
    @ViewBuilder let content: Content

    private var offset: CGSize {
        SettingsFloatingPanel.clamp(
            CGSize(
                width: moved.width + dragging.width,
                height: moved.height + dragging.height
            ),
            in: bounds
        )
    }

    var body: some View {
        let start = SettingsFloatingPanel.origin(in: bounds)
        return
            card
            .frame(
                width: SettingsTheme.panelWidth,
                height: SettingsFloatingPanel.height(in: bounds)
            )
            .offset(
                x: start.x + offset.width,
                y: start.y + offset.height
            )
    }

    private var card: some View {
        VStack(spacing: 0) {
            grabBar
            content
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
        // panel). It also gives the drag ONE composited layer
        // to translate instead of a stack of primitives.
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    /// The card's handle. The drag gesture lives HERE, not on
    /// the card: a gesture over the whole card would compete
    /// with the diff rows' clicks and with any control the
    /// preview grows later, and losing a click to the container
    /// is the kind of bug nobody reports as a drag bug.
    ///
    /// The grip and the close button are two accessibility
    /// elements, deliberately. A label on the row that CONTAINS
    /// the button either renames the ×, swallows it, or is
    /// dropped — three ways to lose one of the two keys, none
    /// of them visible to a locale check
    /// (`localization-auditor`, 2026-08-11).
    private var grabBar: some View {
        HStack(spacing: 8) {
            grip
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
    }

    /// The grip, and the only thing the drag is attached to.
    /// Its name is an INSTRUCTION, not a verb phrase: the card
    /// moves by gesture alone, and VoiceOver cannot perform a
    /// SwiftUI drag — an imperative would announce a command
    /// that cannot be issued. Same shape as the spaces list's
    /// drag handle, `.help` included so pointer users get it
    /// too.
    private var grip: some View {
        Capsule()
            .fill(SettingsTheme.ink3.opacity(0.5))
            .frame(width: 34, height: 4)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .gesture(
                // A couple of points of slack: without it a
                // click that twitches starts a drag, and the
                // card jumps under a pointer that meant to
                // press nothing.
                DragGesture(minimumDistance: 2)
                    .updating($dragging) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        moved = SettingsFloatingPanel.clamp(
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
            .accessibilityElement()
            .accessibilityLabel(
                L("panel.move_preview", "Drag to move the preview")
            )
            .help(
                L("panel.move_preview", "Drag to move the preview")
            )
    }
}
