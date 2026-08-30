import SwiftUI

/// Heading over related sections in settings dashboard.
struct SettingsGroupHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Titled container card for settings sections with search anchoring (#527,
/// #760, #573).
struct SettingsSection<Content: View>: View {
    let title: String
    private let control: SettingsControl?
    let symbol: String?
    let caption: String?
    let subsection: Bool
    let help: String?
    let modeGated: Bool
    @ViewBuilder let content: Content

    /// Computed-title initializer for unindexed sections
    /// (`SettingsCatalogArgumentTests`).
    init(
        _ title: String,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        help: String? = nil,
        modeGated: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.control = nil
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.help = help
        self.modeGated = modeGated
        self.content = content()
    }

    /// Catalog initializer supplying title and search anchor (#277).
    @MainActor init(
        _ control: SettingsControl,
        symbol: String? = nil,
        caption: String? = nil,
        subsection: Bool = false,
        help: String? = nil,
        modeGated: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = control.text
        self.control = control
        self.symbol = symbol
        self.caption = caption
        self.subsection = subsection
        self.help = help
        self.modeGated = modeGated
        self.content = content()
    }

    var body: some View {
        if let control {
            core.searchAnchorCard(control)
        } else {
            core
        }
    }

    private var core: some View {
        VStack(alignment: .leading, spacing: 8) {
            flashedHeader
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.sectionRadius
                )
                .fill(SettingsTheme.card)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: SettingsTheme.sectionRadius
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
        }
        // Hoisted scroll markers for nested search anchors (#610).
        .overlayPreferenceValue(HoistedRevealAnchorsKey.self) {
            anchors in
            revealMarkers(anchors)
        }
        .transformPreference(HoistedRevealAnchorsKey.self) {
            $0 = []
        }
    }

    private func revealMarkers(
        _ anchors: [SettingsControl]
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(anchors, id: \.id) { target in
                Color.clear
                    .frame(width: 0, height: 0)
                    .searchScrollAnchor(target)
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .allowsHitTesting(false)
    }

    /// Header view with search flash and mode-reveal highlighting (#277,
    /// #760).
    @ViewBuilder private var flashedHeader: some View {
        if let control {
            header
                .searchFlashHeader(control)
                .modeRevealWash(modeGated)
        } else {
            header.modeRevealWash(modeGated)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .foregroundStyle(SettingsTheme.ink2)
                    }
                    Text(title)
                        .foregroundStyle(SettingsTheme.ink)
                        // Section heading accessibility trait for rotor
                        // (#812).
                        .accessibilityAddTraits(.isHeader)
                }
                .font(
                    subsection
                        ? .subheadline.weight(.semibold)
                        : .headline
                )
                if let help {
                    HelpButton(
                        explanation: help,
                        subject: title
                    )
                }
            }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink3)
            }
        }
    }
}
