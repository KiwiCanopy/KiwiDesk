import SwiftUI

/// Capsule segmented picker with animated sliding accent pill (#68).
struct SegmentedPicker<Value: Hashable>: View {
    private let label: String?
    /// A name for VoiceOver alone, where the row's own sentence
    /// already names the control and a drawn label would crowd it.
    private let spokenLabel: String?
    /// Left at its natural width, a strip normally measures its
    /// labels' sum and shares that equally, which shortens the
    /// longest. A strip that hugs its content (#1726) sizes every
    /// segment to the widest label at the selected weight instead.
    private let hugsLabels: Bool
    @Binding private var selection: Value
    private let options: [(title: String, value: Value)]
    /// Optional field help text (#94).
    private let help: String?
    @Namespace private var pillSpace
    @State private var hoveredIndex: Int?
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ label: String? = nil,
        spokenLabel: String? = nil,
        hugsLabels: Bool = false,
        selection: Binding<Value>,
        options: [(title: String, value: Value)],
        help: String? = nil
    ) {
        self.label = label
        self.spokenLabel = spokenLabel
        self.hugsLabels = hugsLabels
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

    @ViewBuilder private var labeledTrack: some View {
        if let name = label ?? spokenLabel {
            track.accessibilityLabel(name)
        } else {
            track
        }
    }

    /// Index of selected option or nil if unmatched
    /// (`SegmentedPickerUnmatchedTests`, #754).
    var selectedIndex: Int? {
        options.firstIndex { $0.value == selection }
    }

    private var segmentsLayout: AnyLayout {
        hugsLabels
            ? AnyLayout(EqualSegmentsLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 2))
    }

    /// A hugging strip sizes each label by the selected weight
    /// whatever the state, so picking never changes its width.
    @ViewBuilder private func labelText(
        _ title: String,
        selected: Bool
    ) -> some View {
        let label = Text(title)
            .font(selected ? .body.weight(.semibold) : .callout)
            .lineLimit(1)
        if hugsLabels {
            Text(title)
                .font(.body.weight(.semibold))
                .hidden()
                .overlay { label }
        } else {
            label
        }
    }

    private var track: some View {
        segmentsLayout {
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
        // ONE Tab stop for the whole control, the way a native
        // segmented control behaves — the segments opt out below
        // (#997).
        .focusable(isEnabled)
        .focused($focused)
        .onChange(of: focused) { _, now in
            // This stop would otherwise ring on every click
            // (`ClickBornFocus`).
            guard now,
                ClickBornFocus.isClickBorn(
                    focusMayBeADescendant: false
                )
            else { return }
            focused = false
        }
        // ← / → only: ↑ / ↓ must still leave the row.
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .accessibilityElement(children: .contain)
        // Group value announcement for accessibility (#812, 2026-08-24).
        .accessibilityValue(
            selectedIndex.map { options[$0].title } ?? ""
        )
        .onChange(of: isEnabled) { _, now in
            if !now { hoveredIndex = nil }
        }
    }

    /// Moves the SELECTION one segment, as a native segmented
    /// control does: a highlight that moved without selecting
    /// would announce a choice the binding never took.
    ///
    /// No `isEnabled` guard — the track is `.focusable(isEnabled)`,
    /// so a disabled control receives no key press to answer.
    private func move(_ direction: Int) -> KeyPress.Result {
        guard
            let next = SegmentedPickerKeys.step(
                from: selectedIndex,
                by: direction,
                count: options.count
            )
        else { return .ignored }
        // Clamped, so an end segment swallows its own arrow
        // rather than letting it walk out of the control.
        if next != selectedIndex { select(options[next].value) }
        return .handled
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
        // Only the focus stop goes, to the track; click,
        // VoiceOver and `isEnabled` stay (#997).
        .focusable(false)
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
        labelText(title, selected: selected)
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
        withAnimation(
            reduceMotion
                ? nil
                : .spring(response: 0.32, dampingFraction: 0.75)
        ) {
            selection = value
        }
    }

    @ViewBuilder private var slidingPill: some View {
        if let index = selectedIndex {
            pill.matchedGeometryEffect(
                id: index,
                in: pillSpace,
                isSource: false
            )
        }
    }

    private var pill: some View {
        Capsule()
            .fill(SettingsTheme.accent)
    }
}

/// Shared geometry metrics for segmented pickers
/// (`SegmentedPickerCoverageTests`, 2026-08-12).
enum SegmentedPickerMetrics {
    static let trackAlpha = 0.08
}
