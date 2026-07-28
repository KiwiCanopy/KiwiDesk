import SwiftUI

/// The one way a Settings drawer renders (#277): a
/// `DisclosureGroup` that owns the anchor pairing part 1 left as
/// a call-site convention — `searchFlashHeader` on the label,
/// `searchAnchorCard` on the whole group, OUTSIDE any card chrome —
/// plus expansion, so a reveal targeting a control *inside* a
/// collapsed drawer opens it before the scroll lands.
///
/// The containment question ("is the reveal target one of
/// mine?") is answered by the `SettingsDrawer` value the call
/// site already mounts — its nested children declarations —
/// never a parent column in the catalog. A direct hit on the
/// drawer's own label does NOT auto-expand: the header is
/// visible and highlighted, and opening it is one honest click
/// (part-1 design call).
///
/// Two chromes, matching the two shapes the tree uses: `.inline`
/// for a drawer inside a `SettingsSection` card (Gaps, the bar
/// colour drawers), `.card` for a standalone drawer that paints
/// its own card (the three "Advanced" drawers). The card chrome
/// anchors outside its padding so `scrollTo(anchor: .top)` lands
/// on the card's edge, not 12 pt inside it — the mistake the
/// part-1 comment block in `SettingsReveal` existed to spell
/// out.
struct SettingsDisclosure<Content: View, Accessory: View>: View {
    enum Chrome {
        /// Inside a section card; `font` styles the label
        /// (`.subheadline` for the bar colour drawers, nil for
        /// the plain Gaps labels).
        case inline(font: Font?)
        /// Standalone: headline label, 12 pt padding, its own
        /// card background.
        case card
    }

    private let control: SettingsControl
    private let childIDs: Set<String>
    private let chrome: Chrome
    /// Call-site expansion state, for a drawer with its own
    /// rules (Gaps force-expands while its values are mixed);
    /// nil means this view owns it.
    private let externalExpansion: Binding<Bool>?
    @State private var internalExpansion = false
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let accessory: () -> Accessory
    @Environment(\.settingsRevealTarget)
    private var revealTarget

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline(font: nil),
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.control = drawer.control
        self.childIDs = drawer.childIDs
        self.chrome = chrome
        self.externalExpansion = isExpanded
        self.content = content
        self.accessory = accessory
    }

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline(font: nil),
        isExpanded: Binding<Bool>? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where Accessory == EmptyView {
        self.init(
            drawer,
            chrome: chrome,
            isExpanded: isExpanded,
            content: content,
            accessory: { EmptyView() }
        )
    }

    var body: some View {
        switch chrome {
        case .inline:
            group.searchAnchorCard(control)
        case .card:
            group
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            Color(
                                nsColor: .controlBackgroundColor
                            )
                        )
                )
                .searchAnchorCard(control)
        }
    }

    private var group: some View {
        DisclosureGroup(isExpanded: expansion) {
            content()
        } label: {
            // The wash goes on the label alone; flashing the
            // group would tint the expanded contents too — the
            // whole-card wash the treatment exists to avoid.
            HStack(spacing: 6) {
                Text(control.text)
                    .font(labelFont)
                accessory()
            }
            .searchFlashHeader(control)
        }
        // Reads only — the reveal fields keep one writer and
        // one clearer (`SettingsView`); an observer that also
        // cleared could blank a request before the scroll
        // driver ran (the part-1 #326 bug).
        .onChange(of: revealTarget) { _, target in
            expand(revealing: target)
        }
        .onAppear { expand(revealing: revealTarget) }
    }

    private var labelFont: Font? {
        switch chrome {
        case .inline(let font): return font
        case .card: return .headline
        }
    }

    private var expansion: Binding<Bool> {
        externalExpansion ?? $internalExpansion
    }

    private func expand(revealing target: String?) {
        guard childIDs.contains(target ?? "") else { return }
        expansion.wrappedValue = true
    }
}
