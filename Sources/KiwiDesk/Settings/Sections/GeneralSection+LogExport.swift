import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: the log export (#1209) — rung zero of the
/// recovery ladder, the first thing a user in trouble should do,
/// because it changes nothing. One settings row (owner ruling
/// 2026-09-02): the label and its help on the left, the range menu
/// and the export button together on the right, the caption below.
extension GeneralSection {
    @ViewBuilder var exportLogRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            SettingsRowShape {
                SettingsRowLabel(
                    label: L(
                        "general.advanced.log.export",
                        "Export log"
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
                )
            } control: {
                HStack(spacing: 8) {
                    // Named for VoiceOver by the range key: the row's
                    // visible label names the export, not the menu.
                    Picker("", selection: $logRange) {
                        ForEach(
                            SettingsModel.LogExportRange.allCases
                        ) {
                            Text($0.title).tag($0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.large)
                    .accessibilityLabel(
                        L("general.advanced.log.range", "Time range")
                    )
                    .accessibilityValue(logRange.title)
                    Button {
                        let choice = logRange
                        Task { await model.exportLog(choice) }
                    } label: {
                        Label(
                            L(
                                "general.advanced.log.export.button",
                                "Export…"
                            ),
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                    .settingsActionButton()
                    // Always drawn, faded when idle (gui.md ▸ grey,
                    // don't hide).
                    ProgressView()
                        .controlSize(.small)
                        .opacity(model.isExportingLog ? 1 : 0)
                        .accessibilityHidden(!model.isExportingLog)
                    Spacer()
                }
            }
            Text(
                L(
                    "general.advanced.log.export.caption",
                    "Saves KiwiDesk's log for that time range to a "
                        + "text file you choose — the file to attach "
                        + "to a bug report. Changes nothing."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
