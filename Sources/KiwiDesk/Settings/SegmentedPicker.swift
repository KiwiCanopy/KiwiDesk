import SwiftUI

/// The tab-style option chooser shared across the settings
/// (#68): a capsule track where the selection is a solid
/// white pill (the native tab-switcher look; dark mode gets
/// a light gray) and the selected label is larger and
/// semibold. Liquid Glass was tried and dropped here — the
/// glass layer refracted whatever sat behind it, reading as
/// blur under the text and stray tint. ONE persistent pill
/// slides between segments via matched geometry: each
/// segment anchors a frame and the pill adopts the selected
/// anchor, so a selection change moves the same view (a
/// slide) instead of swapping styling between labels, which
/// crossfades.
///
/// Precondition: option `value`s must be unique — duplicates
/// would make two segments claim the pill's anchor.
struct SegmentedPicker<Value: Hashable>: View {
    private let label: String?
    @Binding private var selection: Value
    private let options: [(title: String, value: Value)]
    @Namespace private var pillSpace
    @Environment(\.colorScheme) private var scheme

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
            HStack {
                Text(label)
                    .frame(
                        width: SettingsMetrics.labelColumn,
                        alignment: .leading
                    )
                labeledTrack
            }
        } else {
            labeledTrack
        }
    }

    /// The label attaches only when one exists — an empty
    /// accessibility label on the unlabeled instances (icon
    /// picker tabs) would override the group's inferred name.
    @ViewBuilder private var labeledTrack: some View {
        if let label {
            track.accessibilityLabel(label)
        } else {
            track
        }
    }

    private var selectedIndex: Int? {
        options.firstIndex { $0.value == selection }
    }

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { index in
                segment(options[index], index: index)
            }
        }
        .background { slidingPill }
        .padding(3)
        .background(
            Capsule().fill(Color.primary.opacity(0.08))
        )
        .overlay(
            Capsule().strokeBorder(
                Color.primary.opacity(0.08),
                lineWidth: 0.5
            )
        )
        .accessibilityElement(children: .contain)
    }

    private func segment(
        _ option: (title: String, value: Value),
        index: Int
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
        .matchedGeometryEffect(
            id: index,
            in: pillSpace,
            isSource: true
        )
        .accessibilityAddTraits(
            selected ? [.isSelected] : []
        )
    }

    private func segmentLabel(
        _ title: String,
        selected: Bool
    ) -> some View {
        Text(title)
            // A real font-size step, not `scaleEffect` — a
            // scale rasterizes the drawn text and stretches
            // it, which reads as blur. The equal-width
            // segments absorb the width change.
            .font(
                selected
                    ? .body.weight(.semibold)
                    : .callout
            )
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
    }

    /// The one persistent pill. It adopts the selected
    /// segment's anchored frame, so a selection change slides
    /// this same view. Hidden when the bound value matches no
    /// option (hand-edited config).
    @ViewBuilder private var slidingPill: some View {
        if let index = selectedIndex {
            pill.matchedGeometryEffect(
                id: index,
                in: pillSpace,
                isSource: false
            )
        }
    }

    /// The solid pill: white in light mode, a light gray in
    /// dark, carrying the slider thumb's exact shadow so the
    /// two controls read as one family. (The earlier soft
    /// glass-era shadow read as the pill "fading out"; this
    /// crisp one doesn't.)
    private var pill: some View {
        Capsule()
            .fill(
                scheme == .dark
                    ? Color.white.opacity(0.28)
                    : Color.white
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.primary.opacity(0.06),
                    lineWidth: 0.5
                )
            )
            .shadow(
                color: .black.opacity(0.25),
                radius: 2,
                y: 1
            )
    }
}
