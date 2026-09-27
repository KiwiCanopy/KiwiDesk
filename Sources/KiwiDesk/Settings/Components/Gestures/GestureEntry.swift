import SwiftUI

/// One Mouse & trackpad entry (#1726): a drawn picture, the
/// sentence that carries the gesture, and the entry's own control
/// where it has one. The picture plays on hover and rests on its
/// key frame otherwise; under Reduce Motion it never moves.
struct GestureEntry<Picture: View, Control: View>: View {
    let text: String
    @ViewBuilder let picture: (CGFloat) -> Picture
    @ViewBuilder let control: () -> Control
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var phase: CGFloat = 0

    init(
        _ text: String,
        @ViewBuilder picture: @escaping (CGFloat) -> Picture,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.text = text
        self.picture = picture
        self.control = control
    }

    var body: some View {
        // The control takes the full row below: squeezed into the
        // sentence's column, a two-option picker truncates.
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                GesturePlate { picture(hovering ? phase : 1) }
                    .animation(
                        reduceMotion || !hovering
                            ? nil
                            : .easeInOut(duration: 1.6)
                                .repeatForever(autoreverses: false),
                        value: phase
                    )
                    .accessibilityHidden(true)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onHover { inside in
                hovering = inside && !reduceMotion
                phase = hovering ? 1 : 0
            }
            control()
        }
        .padding(.vertical, 4)
    }
}

extension GestureEntry where Control == EmptyView {
    init(
        _ text: String,
        @ViewBuilder picture: @escaping (CGFloat) -> Picture
    ) {
        self.init(text, picture: picture) { EmptyView() }
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
