import KiwiDeskCore
import SwiftUI

/// Standard layout preset card (#789).
struct PresetCard: View {
    static let padding: CGFloat = 12
    static let buttonRowSpacing: CGFloat = 8

    /// Declared minimum card layout width (`PresetGridFloorTests`, #862).
    static let minimumWidth: CGFloat = 280

    let layout: StandardLayout
    let sizes: [CGSize]?
    @ObservedObject var model: SettingsModel
    let connectedScreens: Int
    let onPreview: (PresetPreviewRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PresetScreenCard(layout: layout, liveSizes: sizes)
            titleRow
            Text(layout.displaySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Self.buttonRowSpacing) {
                layoutsButton
                applyButton
            }
        }
        .padding(Self.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SettingsTheme.sunken)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(SettingsTheme.hairline)
        }
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(layout.displayName).font(.headline)
            if layout.isStandard {
                BadgeChip(
                    label: L("presets.standard_badge", "standard")
                )
            }
        }
    }

    /// Opens layout preview sheet (#859).
    private var layoutsButton: some View {
        Button(L("presets.layouts", "Layouts")) {
            onPreview(
                PresetPreviewRequest(
                    layout: layout,
                    liveSizes: sizes
                )
            )
        }
        .controlSize(.large)
        .settingsActionButton()
    }

    /// Applies the preset after confirmation; it drops staged
    /// edits like the profile actions (#515). Greyed, never
    /// hidden (#171), WITH the reason — "why is Apply dead" has
    /// two answers and the stored-profile one contradicts the
    /// header (#518) — and both answers are `ProfilesGates`':
    /// a predicate re-derived here could grey a row the census
    /// says is live.
    @ViewBuilder private var applyButton: some View {
        let reason = gates.inertReason(
            for: .profiles(.presetsApply)
        )
        let button = Button(L("presets.apply", "Apply")) {
            model.discardingEdits(
                message: L(
                    "discard.apply_preset.message",
                    "Applying a preset replaces the edits you "
                        + "haven't saved."
                ),
                confirmLabel: L(
                    "discard.apply_preset.confirm",
                    "Discard & apply"
                )
            ) { model.applyStandardPreset(layout) }
        }
        .controlSize(.large)
        .disabled(reason != nil)
        .help(reason.map(ProfilesGateHelp.sentence) ?? "")
        if reason == nil, layout.isStandard,
            model.profileSummaries.isEmpty
        {
            button.buttonStyle(.borderedProminent)
        } else {
            button.settingsActionButton()
        }
    }

    private var gates: ProfilesGates {
        ProfilesGates(
            editingStoredProfile: model.editingStoredProfile,
            connectedScreens: connectedScreens,
            presetScreens: layout.screenCount
        )
    }
}
