import SwiftUI

/// Capsule segmented picker with animated sliding accent pill (#68).
struct SegmentedPicker<Value: Hashable>: View {
    private let label: String?
    /// A name for VoiceOver alone, where the row's own sentence
    /// already names the control and a drawn label would crowd it.
    private let spokenLabel: String?
    /// What VoiceOver reads for the selection, where the option's
    /// title alone would not say it — or nothing is selected.
    private let spokenValue: String?
    /// Left at its natural width, a strip normally measures its
    /// labels' sum and shares that equally, which shortens the
    /// longest. A strip that hugs its content (#1726) sizes every
    /// segment to the widest label at the selected weight instead.
    let hugsLabels: Bool
    /// Each segment keeps its own label's width, reserved at the
    /// selected weight so picking never changes it, without the
    /// equal sizing `hugsLabels` adds — a strip whose longest label
    /// must not cost every segment its width (#2246).
    let reservesWeight: Bool
    /// A key that stands in for a segment's title while shown —
    /// under the pointer, or every segment's while `showsHints` —
    /// in a width reserved for the wider of the two, so the strip
    /// never changes size (#1229 ▸ Tab bar). Read as the segment's
    /// VoiceOver hint, never its name. A new caller adds its ground
    /// to the contrast suite's pairings.
    let hints: [Value: String]
    let showsHints: Bool
    /// The words VoiceOver reads a hint in.
    private let spokenHint: (String) -> String
    /// A segment's name for VoiceOver where its title is a glyph
    /// a screen reader cannot say (#2460); the title otherwise.
    private let spokenTitles: [Value: String]
    @Binding private var selection: Value
    private let options: [(title: String, value: Value)]
    /// Optional field help text (#94).
    private let help: String?
    /// A neutral pill for a choice no hue may mark (#2777 ruling 14).
    let neutral: Bool
    @Namespace private var pillSpace
    @State var hoveredIndex: Int?
    /// The segment under the pointer, selected or not.
    @State var pointerIndex: Int?
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
    @Environment(\.isEnabled) var isEnabled
    /// KiwiHub's selection inside it (#2569); elsewhere its defaults
    /// are this picker's own Settings tokens.
    @Environment(\.kiwiHubPaint) var paint

    init(
        _ label: String? = nil,
        spokenLabel: String? = nil,
        spokenValue: String? = nil,
        hugsLabels: Bool = false,
        reservesWeight: Bool = false,
        hints: [Value: String] = [:],
        showsHints: Bool = false,
        spokenHint: @escaping (String) -> String = { $0 },
        spokenTitles: [Value: String] = [:],
        selection: Binding<Value>,
        options: [(title: String, value: Value)],
        help: String? = nil,
        neutral: Bool = false
    ) {
        self.label = label
        self.spokenLabel = spokenLabel
        self.spokenValue = spokenValue
        self.hugsLabels = hugsLabels
        self.reservesWeight = reservesWeight
        self.hints = hints
        self.showsHints = showsHints
        self.spokenHint = spokenHint
        self.spokenTitles = spokenTitles
        self._selection = selection
        self.options = options
        self.help = help
        self.neutral = neutral
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

    /// The drawn face; `track` adds focus and accessibility.
    private var trackFace: some View {
        segmentsLayout {
            ForEach(options.indices, id: \.self) { index in
                segment(options[index], index: index)
            }
        }
        .background { slidingPill }
        .padding(3)
        .background(Capsule().fill(paint.fill(SettingsTheme.trackFill)))
        .overlay(
            Capsule().strokeBorder(
                paint.fill(SettingsTheme.trackFill),
                lineWidth: 0.5
            )
        )
    }

    private var track: some View {
        trackFace
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
                spokenValue ?? selectedIndex.map { options[$0].title } ?? ""
            )
            .onChange(of: isEnabled) { _, now in
                if !now {
                    hoveredIndex = nil
                    pointerIndex = nil
                }
            }
            // A panel ordered out under the pointer sends no exit.
            .onDisappear {
                hoveredIndex = nil
                pointerIndex = nil
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
                hint: hints[option.value],
                selected: selected,
                index: index
            )
        }
        .buttonStyle(
            SegmentPressStyle(presses: isEnabled && !selected)
        )
        // Only the focus stop goes, to the track; click,
        // VoiceOver and `isEnabled` stay (#997).
        .focusable(false)
        .accessibilityLabel(spokenTitles[option.value] ?? option.title)
        .onHover { inside in
            if inside, isEnabled {
                pointerIndex = index
            } else if pointerIndex == index {
                pointerIndex = nil
            }
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
        .accessibilityHint(hints[option.value].map(spokenHint) ?? "")
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
            .fill(
                neutral
                    ? AnyShapeStyle(SettingsTheme.chipHover)
                    : paint.fill(paint.selection)
            )
    }

    /// An unselected label's ink: the theme's, or on KiwiHub's Fill
    /// the panel's own hierarchy and its hover ink (gui.md).
    func restInk(_ index: Int) -> AnyShapeStyle {
        guard paint.tinted else { return AnyShapeStyle(SettingsTheme.ink) }
        if hoveredIndex == index, let ink = paint.hoverInk {
            return AnyShapeStyle(ink)
        }
        return AnyShapeStyle(.primary)
    }
}
