import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: the log export (#1209) — rung zero of the
/// recovery ladder, the first thing a user in trouble should do,
/// because it changes nothing. The action-row shape (#2439): the
/// range menu, then the button it feeds, trailing.
extension GeneralSection {
    @ViewBuilder var exportLogRows: some View {
        SettingsActionRow(
            title: L("general.advanced.log.row", "Log"),
            caption: L(
                "general.advanced.log.export.caption",
                "The log for that time range, to attach to a "
                    + "bug report. Changes nothing."
            ),
            help: L(
                "general.advanced.log.export.help",
                "If you can make the problem happen again, "
                    + "do that first, then export — the range "
                    + "counts back from now. The file holds "
                    + "only what KiwiDesk itself wrote to the "
                    + "macOS log; it names the apps and "
                    + "windows it managed in that time, so "
                    + "glance through it before attaching."
            )
        ) {
            HStack(spacing: 6) {
                // Always drawn, faded when idle (gui.md ▸ grey,
                // don't hide).
                ProgressView()
                    .controlSize(.small)
                    .opacity(model.isExportingLog ? 1 : 0)
                    .accessibilityHidden(!model.isExportingLog)
                // Named for VoiceOver by the range key: nothing
                // visible names the menu, the button names the
                // export.
                Picker("", selection: $logRange) {
                    ForEach(SettingsModel.LogExportRange.allCases) {
                        Text($0.title).tag($0)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .neutralMenuLabel()
                .fixedSize()
                .accessibilityLabel(
                    L("general.advanced.log.range", "Time range")
                )
                .accessibilityValue(logRange.title)
                .searchAnchored(
                    SettingsCatalog.general.generalAdvanced
                        .children.logRange
                )
                Button(advancedExportLabel) {
                    let choice = logRange
                    Task { await model.exportLog(choice) }
                }
                .settingsActionButton()
                .accessibilityLabel(
                    SettingsCatalog.general.generalAdvanced
                        .children.exportLog.text
                )
            }
        }
        .searchAnchored(
            SettingsCatalog.general.generalAdvanced.children
                .exportLog
        )
    }

    /// The short label both export buttons wear; each names its
    /// export for VoiceOver.
    var advancedExportLabel: String {
        L("general.advanced.action.export", "Export…")
    }

    /// The problem alert — built from the problem it narrates
    /// (#843's `presenting:` shape), cleared on dismiss.
    var logExportProblemBinding: Binding<Bool> {
        Binding(
            get: { model.logExportProblem != nil },
            set: { if !$0 { model.logExportProblem = nil } }
        )
    }
}
