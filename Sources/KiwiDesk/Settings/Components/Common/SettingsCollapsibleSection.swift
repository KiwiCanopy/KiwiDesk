import SwiftUI

/// A section card that collapses (#1741): a peer of the page's
/// sections, so it IS a `SettingsSection` — the same plain
/// `.headline` title and plate — and the disclosure is the plate's
/// first row, the summary beside a chevron, the whole row one
/// control. Shut, the card keeps that row, so it never shrinks to
/// a bare heading; open, the entries follow it inside the card.
/// Search opens it on a child hit, as a drawer does; `onToggle`
/// hears only the user's own click on the disclosure, never that.
struct SettingsCollapsibleSection<Content: View>: View {
    private let control: SettingsControl
    private let drawer: any AnySettingsDrawer
    private let modeGated: Bool
    private let summary: String
    @Binding private var isExpanded: Bool
    private let onToggle: ((Bool) -> Void)?
    @ViewBuilder private let content: () -> Content
    @Environment(\.settingsRevealTarget)
    private var revealTarget

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        isExpanded: Binding<Bool>,
        summary: String,
        modeGated: Bool = false,
        onToggle: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onToggle = onToggle
        self.control = drawer.control
        self.drawer = drawer
        self._isExpanded = isExpanded
        self.summary = summary
        self.modeGated = modeGated
        self.content = content
    }

    var body: some View {
        SettingsSection(control, modeGated: modeGated) {
            // Not a heading: the section's title above is, and one
            // card lists once in the rotor.
            SettingsDisclosureButton(
                isExpanded: clicked,
                isHeading: false
            ) {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(SettingsTheme.ink3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel(summary)
            if isExpanded {
                SettingsTheme.hairline.frame(height: 1)
                content()
            }
        }
        .onChange(of: revealTarget) { _, target in
            expand(revealing: target)
        }
        .onAppear { expand(revealing: revealTarget) }
    }

    /// The expansion as the disclosure writes it: told to
    /// `onToggle` before it lands, so the content mounts knowing.
    private var clicked: Binding<Bool> {
        Binding(
            get: { isExpanded },
            set: { open in
                onToggle?(open)
                isExpanded = open
            }
        )
    }

    private func expand(revealing target: String?) {
        guard drawer.shouldExpand(revealing: target) else { return }
        isExpanded = true
    }
}
