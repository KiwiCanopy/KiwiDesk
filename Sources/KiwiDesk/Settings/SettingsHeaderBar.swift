import KiwiDeskCore
import SwiftUI

/// Unified settings header bar for Home and area screens (#678).
struct SettingsHeaderBar: View {
    @ObservedObject var model: SettingsModel
    @State private var searchExpanded = false
    @Environment(\.settingsWidth) private var width
    @Environment(\.shellSpace) private var shellSpace

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
                if let name = model.editingProfile {
                    notLoadedRow(name)
                }
                if let status = statusText {
                    statusRow(status)
                }
            }
            // The Lua editor's Save refuses through it too (#2206),
            // and General opens that editor on a profileless page.
            if showsProfileContext || model.editingLua,
                let warning = model.profileWarning
            {
                warningRow(warning)
            }
            // Another Mac's change landed under unsaved edits (#2324).
            if let arrived = model.sync.arrived {
                arrivedRow(arrived)
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

    /// The shell's namespace while `destination` is the card a page
    /// grew out of, so only that page's title travels.
    private func expanding(
        _ destination: SettingsDestination
    ) -> Namespace.ID? {
        model.nav.shellMotion == .expand(destination) ? shellSpace : nil
    }

    @ViewBuilder private var titleRow: some View {
        if model.showsSimple {
            simpleTitleRow
        } else {
            advancedTitleRow
        }
    }

    private var advancedTitleRow: some View {
        HStack(spacing: 12) {
            if let destination {
                backChip
                if !titleYields {
                    Text(destination.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SettingsTheme.ink)
                        .lineLimit(1)
                        .shellMatched(
                            ShellMotion.titleID(destination),
                            in: expanding(destination)
                        )
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
                reveal: { model.nav.pendingReveal = $0 }
            )
            .id(destination)
            if showsProfileContext {
                profileChip
            }
            // The roots carry the switch; a page's way out is Home,
            // and the Lua editor is neither root.
            if destination == nil, !model.editingLua {
                SettingsRootSwitch(model: model)
            }
        }
        .padding(.leading, SettingsHeaderBar.trafficLightInset)
        // The search panel's room ends at this row's trailing edge.
        .coordinateSpace(.named(SearchPanelRoom.headerSpace))
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
                // Shed with the chrome; never wrapped, or a squeezed
                // row stacks it a letter per line.
                if !width.collapsesChrome {
                    Text(L("home.back", "Home"))
                        .font(.callout)
                        .fixedSize()
                }
            }
            .foregroundStyle(SettingsTheme.ink)
            .padding(.horizontal, ChipMetrics.padH)
            .padding(.vertical, ChipMetrics.padV)
            // A button chip: it lifts under the pointer (#2377).
            .hoverHighlight(
                cornerRadius: SettingsTheme.chipRadius,
                padding: 0
            )
            .contentShape(ChipMetrics.shape)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("[", modifiers: .command)
        .accessibilityLabel(L("home.back", "Home"))
    }

    /// Profile edit target dropdown chip (#18, #1393), the whole
    /// chip its menu's hit area.
    private var profileChip: some View {
        ProfileEditTargetMenu(model: model)
    }
}
