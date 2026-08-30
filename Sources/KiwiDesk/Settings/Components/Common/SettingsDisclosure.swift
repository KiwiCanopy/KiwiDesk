import SwiftUI

/// Settings drawer with search reveal anchoring and auto-expansion (#277).
///
/// Anchors via `SettingsReveal`, auto-expanding when an interior
/// child is targeted (#610, #760).
struct SettingsDisclosure<Content: View, Accessory: View>: View {
    /// Container chrome variant (`SettingsDisclosureSizeTests`, #1021).
    enum Chrome {
        /// Inside a section card under a hairline rule.
        case inline
        /// Standalone card with background and padding.
        case card
    }

    private let control: SettingsControl
    private let childIDs: Set<String>
    private let chrome: Chrome
    /// Hoists scroll anchor to enclosing section top (#610).
    private let scrollHoisted: Bool
    /// Mode-gated presence (#760).
    private let modeGated: Bool
    private let externalExpansion: Binding<Bool>?
    @State private var internalExpansion = false
    /// Summary phrase displayed while collapsed (#1028).
    private let summary: String?
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let accessory: () -> Accessory
    @Environment(\.settingsRevealTarget)
    private var revealTarget

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline,
        isExpanded: Binding<Bool>? = nil,
        scrollHoisted: Bool = false,
        modeGated: Bool = false,
        summary: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.control = drawer.control
        self.childIDs = drawer.childIDs
        self.chrome = chrome
        self.scrollHoisted = scrollHoisted
        self.modeGated = modeGated
        self.summary = summary
        self.externalExpansion = isExpanded
        self.content = content
        self.accessory = accessory
    }

    init<Children>(
        _ drawer: SettingsDrawer<Children>,
        chrome: Chrome = .inline,
        isExpanded: Binding<Bool>? = nil,
        scrollHoisted: Bool = false,
        modeGated: Bool = false,
        summary: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) where Accessory == EmptyView {
        self.init(
            drawer,
            chrome: chrome,
            isExpanded: isExpanded,
            scrollHoisted: scrollHoisted,
            modeGated: modeGated,
            summary: summary,
            content: content,
            accessory: { EmptyView() }
        )
    }

    var body: some View {
        switch chrome {
        case .inline:
            if scrollHoisted {
                inlineRuled.preference(
                    key: HoistedRevealAnchorsKey.self,
                    value: [control]
                )
            } else {
                inlineRuled.searchAnchorCard(control)
            }
        case .card:
            group
                .padding(12)
                .background(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.sectionRadius
                    )
                    .fill(SettingsTheme.card)
                    .overlay(
                        RoundedRectangle(
                            cornerRadius:
                                SettingsTheme.sectionRadius
                        )
                        .strokeBorder(
                            modeGated
                                ? SettingsTheme.accent.opacity(
                                    SettingsTheme
                                        .modeGatedStrokeOpacity
                                )
                                : SettingsTheme.hairline,
                            lineWidth: modeGated
                                ? SettingsTheme
                                    .containerStrokeModeGated
                                : SettingsTheme.containerStroke
                        )
                    )
                )
                .searchAnchorCard(control)
        }
    }

    private var inlineRuled: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsTheme.hairline.frame(height: 1)
            group
        }
        .padding(.top, 4)
    }

    private var group: some View {
        DisclosureGroup(isExpanded: expansion) {
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(10)
            .background(
                RoundedRectangle(
                    cornerRadius:
                        SettingsTheme.disclosureRadius
                )
                .fill(SettingsTheme.sunken)
                .overlay(
                    RoundedRectangle(
                        cornerRadius:
                            SettingsTheme.disclosureRadius
                    )
                    .strokeBorder(SettingsTheme.hairline)
                )
            )
        } label: {
            Text(control.text)
                .font(SettingsDrawerHeader.tier.weight(.semibold))
                .searchFlashHeader(control)
                .modeRevealWash(modeGated)
        }
        .disclosureGroupStyle(
            SettingsDisclosureStyle(
                summary: summary,
                accessory: accessory
            )
        )
        .onChange(of: revealTarget) { _, target in
            expand(revealing: target)
        }
        .onAppear { expand(revealing: revealTarget) }
    }

    private var expansion: Binding<Bool> {
        externalExpansion ?? $internalExpansion
    }

    private func expand(revealing target: String?) {
        guard childIDs.contains(target ?? "") else { return }
        expansion.wrappedValue = true
    }
}
