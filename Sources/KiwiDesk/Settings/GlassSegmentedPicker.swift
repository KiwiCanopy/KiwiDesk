import SwiftUI

/// The tab-style option chooser shared across the settings
/// (#68): a capsule track where the selected segment carries a
/// Liquid Glass pill — the real `glassEffect` on macOS 26, a
/// material stand-in on earlier systems — and its label zooms
/// slightly. On macOS 26 the glass is applied to the LABEL
/// itself, never layered above it: glass composites over
/// sibling content in a `GlassEffectContainer`, so a pill
/// behind the text would blur it; a view's own content renders
/// crisply on its glass. Changing the selection morphs/slides
/// the pill between segments.
///
/// Precondition: option `value`s must be unique — duplicates
/// would render two selected pills fighting over one
/// glass/geometry identity.
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "")
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
            segmentLabel(option.title, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            selected ? [.isSelected] : []
        )
    }

    /// The label carries the glass itself when selected (its
    /// content then draws ON the glass, not blurred under
    /// it); the pre-26 fallback keeps the material pill as a
    /// background, where ordinary z-ordering already keeps
    /// the text on top.
    @ViewBuilder private func segmentLabel(
        _ title: String,
        selected: Bool
    ) -> some View {
        let base = Text(title)
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
        if #available(macOS 26.0, *) {
            if selected {
                base
                    .glassEffect(
                        .regular.interactive(),
                        in: Capsule()
                    )
                    .glassEffectID("pill", in: pillSpace)
            } else {
                base
            }
        } else {
            base.background {
                if selected {
                    fallbackPill.matchedGeometryEffect(
                        id: "pill",
                        in: pillSpace
                    )
                }
            }
        }
    }

    /// The bordered material capsule standing in for Liquid
    /// Glass on macOS 14/15.
    private var fallbackPill: some View {
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
