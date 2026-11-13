import KiwiDeskCore
import SwiftUI

/// Simple's Mac Checklist block (#3290, amending #2737): a header
/// line that opens the checklist in Advanced, then only the
/// essentials still open, each as Advanced's own `MacSettingRow`.
/// With every essential done it folds to one quiet line, the same
/// door. The tour's exit lands Simple scrolled here (#1365).
struct SimpleMacChecklist: View {
    @ObservedObject var model: SettingsModel

    /// The scroll id the tour's landing scrolls to.
    static let anchor = "simple.mac_checklist"

    var body: some View {
        let open = Self.openEssentials(
            states: model.macChecklistStates,
            ticks: model.macChecklistTicks
        )
        Group {
            if open.isEmpty {
                allDone
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    header
                    rows(open)
                        .padding(SettingsMetrics.sectionPlateInset)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SettingsCardPlate())
                }
            }
        }
        .id(Self.anchor)
    }

    /// The essentials macOS does not yet report set, in the
    /// checklist's order; a row leaves once it is done.
    static func openEssentials(
        states: [MacSetting: MacSettingState],
        ticks: Set<MacSetting>
    ) -> [MacChecklistKey] {
        let done = Set(
            MacChecklistProgress.verdicts(states: states, ticks: ticks)
                .filter(\.done).map(\.setting)
        )
        return MacChecklistRowOrder.essentialSettings.compactMap {
            guard case .macChecklist(let key) = $0,
                let setting = key.setting, !done.contains(setting)
            else { return nil }
            return key
        }
    }

    private var title: String { SettingsDestination.macChecklist.title }

    private var progress: String {
        MacChecklistText.cardProgress(
            done: model.macChecklistDone,
            total: MacChecklistProgress.total
        )
    }

    /// The whole line is one door into Advanced's checklist.
    private var header: some View {
        door {
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(SettingsTheme.ink)
                Spacer(minLength: 8)
                Text(progress)
                    .font(.subheadline)
                    .foregroundStyle(SettingsTheme.ink2)
                MacChecklistTicks(model, font: MacSettingRow.chipFont)
                chevron
            }
        }
        .accessibilityLabel(title)
        .accessibilityValue(progress)
        .accessibilityAddTraits(.isHeader)
    }

    /// 4 of 4: one quiet line on the page, no card fill.
    private var allDone: some View {
        door {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(SettingsTheme.groupHeading)
                Text(
                    L(
                        "simple.mac_checklist.all_line",
                        "%1$@ · %2$@",
                        title,
                        progress
                    )
                )
                .foregroundStyle(SettingsTheme.ink2)
                chevron
                Spacer(minLength: 0)
            }
            .font(.subheadline)
        }
        .accessibilityLabel(title)
        .accessibilityValue(progress)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SettingsTheme.ink3)
    }

    private func door(
        @ViewBuilder _ label: () -> some View
    ) -> some View {
        Button {
            model.openAdvanced(SettingsAnchor(destination: .macChecklist))
        } label: {
            label().contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
    }

    private func rows(_ open: [MacChecklistKey]) -> some View {
        let chipWidth = MacSettingRow.chipWidth
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(open.enumerated()), id: \.element) {
                index,
                key in
                if index > 0 { Divider() }
                if let setting = key.setting,
                    let control = MacChecklistSection.control(for: key)
                {
                    MacSettingRow(
                        model: model,
                        key: key,
                        setting: setting,
                        control: control,
                        chipWidth: chipWidth
                    )
                }
            }
        }
    }
}
