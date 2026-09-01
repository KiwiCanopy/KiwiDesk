import KiwiDeskCore
import SwiftUI

/// Unified settings header bar for Home and area screens (#678).
struct SettingsHeaderBar: View {
    @ObservedObject var model: SettingsModel
    @State private var searchExpanded = false
    @Environment(\.settingsWidth) private var width
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    private var destination: SettingsDestination? {
        model.destination
    }

    private var showsProfileContext: Bool {
        destination?.showsProfileContext ?? true
    }

    /// Whether area title yields space to expanded search bar.
    private var titleYields: Bool {
        width.collapsesChrome && searchExpanded
    }

    @ViewBuilder var body: some View {
        VStack(spacing: 0) {
            rows
                .zIndex(1)
            SettingsTheme.hairline.frame(height: 1)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            if showsProfileContext {
                if let status = statusText {
                    statusRow(status)
                }
                if let warning = model.profileWarning {
                    warningRow(warning)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.card)
        .onChange(of: destination) { _, _ in
            searchExpanded = false
        }
        .onChange(of: width) { _, now in
            if !now.collapsesChrome { searchExpanded = false }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            if let destination {
                backChip
                if !titleYields {
                    Text(destination.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SettingsTheme.ink)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
            } else if !titleYields {
                identity
            }
            HeaderSearch(
                expanded: $searchExpanded,
                context: searchContext,
                spotlightProfiles:
                    model.profileSummaries.isEmpty,
                value: { [weak model] key in
                    model?.searchValue(for: key)
                },
                reveal: { model.nav.pendingReveal = $0 },
                armModeNotice: { model.nav.pendingModeNotice = $0 }
            )
            .id(destination)
            if showsProfileContext {
                profileChip
            }
            modeSegment
        }
        .padding(.leading, SettingsHeaderBar.trafficLightInset)
    }

    /// "← Home" navigation back button.
    private var backChip: some View {
        Button {
            model.destination = nil
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 11, weight: .semibold))
                if let mark = BrandAssets.appMark {
                    Image(nsImage: mark)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                Text(L("home.back", "Home"))
                    .font(.callout)
            }
            .foregroundStyle(SettingsTheme.ink)
            .chipSurface()
            .contentShape(ChipMetrics.shape)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("[", modifiers: .command)
        .accessibilityLabel(L("home.back", "Home"))
    }

    /// Profile edit target dropdown chip (#18, #209).
    private var profileChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SettingsTheme.accent)
                .frame(width: 8, height: 8)
            ProfileEditTargetMenu(model: model)
        }
        .chipSurface()
    }

    /// Mode segment picker triggering mode reveal wash (#760, #823).
    private var modeSegment: some View {
        SegmentedPicker(
            selection: Binding(
                get: { model.settingsMode },
                set: {
                    model.flipSettingsMode(
                        $0,
                        reduceMotion: reduceMotion
                    )
                }
            ),
            options: [
                (L("mode.simple", "Simple"), SettingsMode.simple),
                (
                    L("mode.power_user", "Power User"),
                    SettingsMode.powerUser
                ),
            ]
        )
        .fixedSize()
        .accessibilityLabel(L("home.mode_ax", "Settings mode"))
    }

}
