import SwiftUI

/// A section card that collapses (#1741): a peer of the page's
/// sections, so it wears `SettingsSection`'s `.headline` header and
/// plate, where a drawer that qualifies a card stays a
/// `SettingsDisclosure`. Shut, the plate stays drawn and holds the
/// summary, so the card never shrinks to a bare heading; a click on
/// it opens the card too. Search opens it on a child hit, as a
/// drawer does.
struct SettingsCollapsibleSection<Content: View>: View {
    private let control: SettingsControl
    private let drawer: any AnySettingsDrawer
    private let modeGated: Bool
    private let summary: String
    @Binding private var isExpanded: Bool
    @ViewBuilder private let content: () -> Content
    @Environment(\.settingsRevealTarget)
    private var revealTarget
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        isExpanded: Binding<Bool>,
        summary: String,
        modeGated: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.control = drawer.control
        self.drawer = drawer
        self._isExpanded = isExpanded
        self.summary = summary
        self.modeGated = modeGated
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsDisclosureButton(isExpanded: $isExpanded) {
                Text(control.text)
                    .foregroundStyle(SettingsTheme.ink)
                    .searchFlashHeader(control)
                    .modeRevealWash(modeGated)
                Spacer(minLength: 0)
            }
            .font(.headline)
            // Shut, the label carries the summary the resting
            // plate draws, as the drawer header's label does.
            .accessibilityLabel(
                isExpanded ? control.text : control.text + ", " + summary
            )
            plate
        }
        .searchAnchorCard(control)
        .onChange(of: revealTarget) { _, target in
            expand(revealing: target)
        }
        .onAppear { expand(revealing: revealTarget) }
    }

    private var plate: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isExpanded {
                content()
            } else {
                resting
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SettingsTheme.sectionRadius)
                .fill(SettingsTheme.card)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.sectionRadius
                    )
                    .strokeBorder(
                        modeGated
                            ? SettingsTheme.accent.opacity(
                                SettingsTheme.modeGatedStrokeOpacity
                            )
                            : SettingsTheme.hairline,
                        lineWidth: modeGated
                            ? SettingsTheme.containerStrokeModeGated
                            : SettingsTheme.containerStroke
                    )
                )
        )
    }

    /// The summary at rest: a second click target, hidden from
    /// VoiceOver since the header button is the one control and
    /// already carries it.
    private var resting: some View {
        Text(summary)
            .font(.callout)
            .foregroundStyle(SettingsTheme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(
                    reduceMotion ? nil : .easeOut(duration: 0.18)
                ) {
                    isExpanded = true
                }
            }
            .accessibilityHidden(true)
    }

    private func expand(revealing target: String?) {
        guard drawer.shouldExpand(revealing: target) else { return }
        isExpanded = true
    }
}
