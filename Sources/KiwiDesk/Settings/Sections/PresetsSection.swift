import KiwiDeskCore
import SwiftUI

/// Built-in layout presets section grouped by screen count (#53, #678).
struct PresetsSection: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.settingsWidth) private var band
    @State private var otherSetupsExpanded = false
    @State private var previewRequest: PresetPreviewRequest?

    var body: some View {
        SettingsSection(
            SettingsCatalog.profiles.presetsCard,
            caption: rowsCaption
        ) {
            if model.profileSummaries.isEmpty {
                Text(startHereText)
                    .font(.callout)
                    .fontWeight(.medium)
            }
            liveGroup
            otherSetups
        }
        .sheet(item: $previewRequest) { request in
            PresetPreviewSheet(
                layout: request.layout,
                liveSizes: request.liveSizes
            ) { previewRequest = nil }
        }
    }

    private var startHereText: String {
        L(
            "presets.start_here",
            "Start here — apply a preset for your "
                + "setup, then adjust anything from "
                + "any tab."
        )
    }

    private var rowsCaption: String {
        L(
            "presets.caption",
            "Applying one saves it as a real profile you can "
                + "then edit."
        )
    }

    private var liveCount: Int { liveSizes.count }

    /// Live display dimensions in positional order for starter presets.
    private var liveSizes: [CGSize] {
        StarterSetup.sizes(
            displays: model.displays,
            mainID: PositionalDisplays.liveMainID
        )
    }

    @ViewBuilder private var liveGroup: some View {
        let presets = ProfilesFamilyRows.presets(
            forScreens: liveCount,
            sizes: liveSizes
        )
        if presets.isEmpty {
            Text(noPresetsForCount)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            SettingsGroupHeader(liveHeading)
                .padding(.top, 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presets, id: \.name) {
                    presetCard($0, sizes: liveSizes)
                }
            }
        }
    }

    private var liveHeading: String {
        liveCount == 1
            ? L("presets.for_your.one", "For your 1 screen")
            : L(
                "presets.for_your.many",
                "For your %1$d screens",
                liveCount
            )
    }

    private var noPresetsForCount: String {
        L(
            "presets.none_for_count",
            "No built-in layout plans for this many screens — "
                + "the ones below still apply once you connect "
                + "the screens they are for."
        )
    }

    /// Presets for disconnected screen counts in disclosure (#1028).
    @ViewBuilder private var otherSetups: some View {
        let others = ProfilesFamilyRows.presets(
            excludingScreens: liveCount
        )
        if !others.isEmpty {
            SettingsDisclosure(
                SettingsCatalog.profiles.presetsOther,
                isExpanded: $otherSetupsExpanded,
                scrollHoisted: true
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(otherCounts(others), id: \.self) {
                        count in
                        otherCountGroup(count, in: others)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func otherCounts(
        _ others: [StandardLayout]
    ) -> [Int] {
        Array(Set(others.map(\.screenCount))).sorted()
    }

    @ViewBuilder private func otherCountGroup(
        _ count: Int,
        in others: [StandardLayout]
    ) -> some View {
        Text(
            count == 1
                ? L("profiles.screens.one", "1 screen")
                : L(
                    "profiles.screens.many",
                    "%1$d screens",
                    count
                )
        )
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(
                others.filter { $0.screenCount == count },
                id: \.name
            ) { presetCard($0, sizes: nil) }
        }
    }

    /// Card wrapper maintaining signature for `ProfilesGateWiringTests`
    /// (#859).
    private func presetCard(
        _ layout: StandardLayout,
        sizes: [CGSize]?
    ) -> some View {
        PresetCard(
            layout: layout,
            sizes: sizes,
            model: model,
            connectedScreens: liveCount
        ) { previewRequest = $0 }
    }

    /// Grid items capped by width class (`SettingsWidthClass`, #862).
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: PresetCard.minimumWidth),
                spacing: 12
            ),
            count: band.presetColumnCap
        )
    }
}
