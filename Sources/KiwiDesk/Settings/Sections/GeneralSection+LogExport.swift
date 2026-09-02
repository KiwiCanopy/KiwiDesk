import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: the log export (#1209) — rung zero of the
/// recovery ladder, the first thing a user in trouble should do,
/// because it changes nothing. Shape: a labelled range menu ABOVE
/// the action it parameterizes, then the button, help and caption
/// in the backup export's arrangement (ui-designer, 2026-09-02).
extension GeneralSection {
    @ViewBuilder var exportLogRows: some View {
        DropdownRow(
            label: L("general.advanced.log.range", "Time range"),
            spokenValue: logRange.title
        ) {
            Picker("", selection: $logRange) {
                ForEach(SettingsModel.LogExportRange.allCases) {
                    Text($0.title).tag($0)
                }
            }
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    let choice = logRange
                    Task { await model.exportLog(choice) }
                } label: {
                    Label(
                        L("general.advanced.log.export", "Export Log…"),
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
                .settingsActionButton()
                .disabled(model.isExportingLog)
                HelpButton(
                    explanation: L(
                        "general.advanced.log.export.help",
                        "If you can make the problem happen again, "
                            + "do that first, then export — the range "
                            + "counts back from now. The file holds "
                            + "only what KiwiDesk itself wrote to the "
                            + "macOS log; it names the apps and "
                            + "windows it managed in that time, so "
                            + "glance through it before attaching."
                    ),
                    subject: L("general.advanced.log.export", "Export Log…")
                )
                // Always drawn, faded when idle: a spinner that
                // appears and vanishes is a layout jump and a
                // conditional the hiding guard refuses.
                ProgressView()
                    .controlSize(.small)
                    .opacity(model.isExportingLog ? 1 : 0)
                    .accessibilityHidden(!model.isExportingLog)
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
