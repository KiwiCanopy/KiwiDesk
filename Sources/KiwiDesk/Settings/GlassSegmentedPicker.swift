import SwiftUI

/// The tab-style option chooser shared across the settings
/// (#68): a capsule track where the selected segment carries a
/// Liquid Glass pill — the real `glassEffect` on macOS 26, a
/// material stand-in on earlier systems — and its label zooms
/// slightly, as if magnified by the glass. Changing the
/// selection slides the pill between segments.
struct GlassSegmentedPicker<Value: Hashable>: View {
    private let label: String?
    @Binding private var selection: Value
    private let options: [(title: String, value: Value)]
    @Namespace private var pillSpace

    init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [(title: String, value: Value)]
    ) {
        self.label = label
        self._selection = selection
        self.options = options
    }

    var body: some View {
        if let label {
            HStack(spacing: 12) {
                Text(label)
                glassTrack
            }
        } else {
            glassTrack
        }
    }

    /// On macOS 26 the track lives in a
    /// `GlassEffectContainer` so the pill renders as one
    /// coherent Liquid Glass element and morphs fluidly when
    /// the selection moves; older systems get the bare track
    /// with the material pill.
    @ViewBuilder private var glassTrack: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer { track }
        } else {
            track
        }
    }

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                segment(options[index])
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
        )
    }

    private func segment(
        _ option: (title: String, value: Value)
    ) -> some View {
        let selected = option.value == selection
        return Button {
            withAnimation(
                .spring(response: 0.32, dampingFraction: 0.75)
            ) {
                selection = option.value
            }
        } label: {
            Text(option.title)
                .font(
                    .callout
                        .weight(selected ? .medium : .regular)
                )
                .scaleEffect(selected ? 1.08 : 1)
                .lineLimit(1)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            if selected {
                pill.matchedGeometryEffect(
                    id: "pill",
                    in: pillSpace
                )
            }
        }
        .accessibilityAddTraits(
            selected ? [.isSelected] : []
        )
    }

    /// The pill under the selected segment: Liquid Glass where
    /// the OS has it, a bordered material capsule otherwise.
    /// `.interactive()` makes the glass respond to clicks; the
    /// `glassEffectID` ties the pill's glass to one identity
    /// so selection changes morph instead of re-materializing.
    @ViewBuilder private var pill: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(
                    .regular.interactive(),
                    in: Capsule()
                )
                .glassEffectID("pill", in: pillSpace)
        } else {
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule().strokeBorder(
                        Color.primary.opacity(0.12),
                        lineWidth: 0.5
                    )
                )
                .shadow(
                    color: .black.opacity(0.12),
                    radius: 2,
                    y: 1
                )
        }
    }
}
