import KiwiDeskCore
import SwiftUI

/// One Mouse & trackpad entry (#1726): a drawn picture, the
/// sentence that carries the gesture, and the entry's own control
/// where it has one. The picture moves only while hovered and rests
/// on its key frame otherwise; under Reduce Motion it never moves.
/// An entry whose `surface` is off greys its picture and sentence
/// and never its control — a greyed control says "you cannot
/// change this", and switching a setting on is always allowed.
struct GestureEntry<Picture: View, Control: View>: View {
    let text: String
    let surface: GestureSurface
    let settings: TilingSettings
    @ViewBuilder let picture: (CGFloat) -> Picture
    @ViewBuilder let control: () -> Control
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var phase: CGFloat = 0

    init(
        _ text: String,
        surface: GestureSurface,
        settings: TilingSettings,
        @ViewBuilder picture: @escaping (CGFloat) -> Picture,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.text = text
        self.surface = surface
        self.settings = settings
        self.picture = picture
        self.control = control
    }

    var body: some View {
        // The control takes the full row below: squeezed into the
        // sentence's column, a two-option picker truncates.
        VStack(alignment: .leading, spacing: 8) {
            explainer
                .modifier(GreyOut(active: surface.isOff(settings)))
            control()
        }
        .padding(.vertical, 4)
    }

    private var explainer: some View {
        HStack(alignment: .top, spacing: 14) {
            // A new identity per hover state: a looping animation
            // ends with the view that ran it, since the rest frame
            // and the loop's target are the same value.
            GesturePlate { picture(hovering ? phase : 1) }
                .id(hovering)
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onHover(perform: hover)
    }

    /// Restarts the gesture from its first frame, then loops it:
    /// two separate updates, since one that moved `phase` straight
    /// to where the rest frame already is would animate nothing.
    private func hover(_ inside: Bool) {
        hovering = inside && !reduceMotion
        phase = 0
        guard hovering else { return }
        DispatchQueue.main.async {
            // The pointer may have left before this turn.
            guard hovering else { return }
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
            ) {
                phase = 1
            }
        }
    }
}

extension GestureEntry where Control == EmptyView {
    init(
        _ text: String,
        surface: GestureSurface,
        settings: TilingSettings,
        @ViewBuilder picture: @escaping (CGFloat) -> Picture
    ) {
        self.init(
            text,
            surface: surface,
            settings: settings,
            picture: picture
        ) { EmptyView() }
    }
}

/// The desktop-dark ground every gesture picture sits on, the
/// Home cards' plate (`SettingsTheme.previewPlate`), sized once.
struct GesturePlate<Content: View>: View {
    static var size: CGSize { CGSize(width: 120, height: 72) }
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content()
        }
        .frame(
            width: Self.size.width,
            height: Self.size.height,
            alignment: .topLeading
        )
        .background(SettingsTheme.previewPlate)
        .clipShape(
            RoundedRectangle(cornerRadius: SettingsTheme.disclosureRadius)
        )
    }
}

/// A heading inside the drawer, one per place the hand is.
struct GestureGroupHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.groupHeading)
            .textCase(.uppercase)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }
}
