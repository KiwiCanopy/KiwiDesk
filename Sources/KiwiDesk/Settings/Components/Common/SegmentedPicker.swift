import SwiftUI

/// The tab-style option chooser shared across the settings
/// (#68): a capsule track where the selection is a solid
/// ACCENT pill with the on-accent ink — the settled "accent
/// marks control fills" convention, which the dark pass
/// extended here: the earlier white pill (light grey in dark)
/// carried the near-white ambient ink at ~3:1 in dark, the
/// worst text pairing in the control set, behind a manual
/// `colorScheme` branch the theme exists to end. Liquid Glass
/// was tried and dropped here — the glass layer refracted
/// whatever sat behind it, reading as blur under the text and
/// stray tint. ONE persistent pill slides between segments via
/// matched geometry: each segment anchors a frame and the pill
/// adopts the selected anchor, so a selection change moves the
/// same view (a slide) instead of swapping styling between
/// labels, which crossfades.
///
/// Precondition: option `value`s must be unique — duplicates
/// would make two segments claim the pill's anchor.
struct SegmentedPicker<Value: Hashable>: View {
    private let label: String?
    @Binding private var selection: Value
    private let options: [(title: String, value: Value)]
    /// Optional `?` popover (#94), label-adjacent — one per
    /// field, never per segment. Unlabeled instances (icon
    /// tabs) have no label to sit beside, so theirs trails
    /// the track instead.
    private let help: String?
    @Namespace private var pillSpace
    @State private var hoveredIndex: Int?
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ label: String? = nil,
        selection: Binding<Value>,
        options: [(title: String, value: Value)],
        help: String? = nil
    ) {
        self.label = label
        self._selection = selection
        self.options = options
        self.help = help
    }

    var body: some View {
        if let label {
            SettingsRowShape {
                SettingsRowLabel(label: label, help: help)
            } control: {
                labeledTrack
            }
        } else if let help {
            HStack {
                labeledTrack
                HelpButton(explanation: help)
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
            track
                .accessibilityLabel(label)
                // The group's choice as its value, so arriving
                // on the track hears "Position, Top" the way a
                // native segmented control says it, before the
                // segments are walked (#812).
                .accessibilityValue(
                    selectedIndex.map { options[$0].title } ?? ""
                )
        } else {
            track
        }
    }

    /// Which segment the pill sits on, or nil when the bound
    /// value matches no option — a hand-edited config, or an
    /// OPTIONAL-valued binding whose two halves disagree (the
    /// shared Corners master, #754). Internal rather than
    /// private because that nil is now load-bearing and
    /// `SegmentedPickerUnmatchedTests` reads it: it is the
    /// difference between "no answer yet" and a picker
    /// asserting an answer the app is not drawing.
    var selectedIndex: Int? {
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
            Capsule().fill(
                Color.primary.opacity(SegmentedPickerMetrics.trackAlpha)
            )
        )
        .overlay(
            Capsule().strokeBorder(
                Color.primary.opacity(SegmentedPickerMetrics.trackAlpha),
                lineWidth: 0.5
            )
        )
        .accessibilityElement(children: .contain)
        .onChange(of: isEnabled) { _, now in
            if !now { hoveredIndex = nil }
        }
    }

    private func segment(
        _ option: (title: String, value: Value),
        index: Int
    ) -> some View {
        let selected = option.value == selection
        return Button {
            select(option.value)
        } label: {
            segmentLabel(
                option.title,
                selected: selected,
                index: index
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            updateHover(
                inside: inside,
                selected: selected,
                index: index
            )
        }
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
        selected: Bool,
        index: Int
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
            // Explicit inks: the selected label rides the
            // accent pill (`accentInk` is the one ink for
            // that), and the rest name `ink` so no ancestor
            // foreground can recolour them (the hierarchical
            // trap).
            .foregroundStyle(
                selected
                    ? SettingsTheme.accentInk
                    : SettingsTheme.ink
            )
            .lineLimit(1)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(
                    Color.primary.opacity(
                        isEnabled && !selected
                            && hoveredIndex == index
                            ? 0.05 : 0
                    )
                )
            )
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hoveredIndex
            )
            .contentShape(Capsule())
    }

    private func updateHover(
        inside: Bool,
        selected: Bool,
        index: Int
    ) {
        if inside, isEnabled, !selected {
            hoveredIndex = index
        } else if hoveredIndex == index {
            hoveredIndex = nil
        }
    }

    private func select(_ value: Value) {
        if reduceMotion {
            selection = value
        } else {
            withAnimation(
                .spring(response: 0.32, dampingFraction: 0.75)
            ) {
                selection = value
            }
        }
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

    /// The solid accent pill. No shadow: the white pill needed
    /// one to lift off a same-luminance track, and its black
    /// shadow was dead in dark anyway; the accent separates by
    /// hue and luminance from the track in both modes, and the
    /// selected state never rides colour alone — the font-step
    /// carries it too.
    private var pill: some View {
        Capsule()
            .fill(SettingsTheme.accent)
    }
}

/// The segmented picker's own metrics, in a non-generic type so
/// they can be named from outside (a `static` stored property is
/// not allowed on a generic one).
///
/// `trackAlpha` is here rather than inline because
/// `SegmentedPickerCoverageTests` MEASURES the unselected label
/// against it: with the number restated in the test, washing the
/// track to 0.6 — a near-white track under a near-white label in
/// dark — passed green, the guard's input never having touched
/// this file (guard-prover, 2026-08-12).
enum SegmentedPickerMetrics {
    /// The track's wash over its card, and the same value its
    /// hairline takes.
    static let trackAlpha = 0.08
}
