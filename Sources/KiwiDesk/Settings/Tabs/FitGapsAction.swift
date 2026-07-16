import Accessibility
import KiwiDeskCore
import SwiftUI

/// Focus Border's opt-in gap transformation (#295). The extra
/// spacing is a transient action parameter; only the calculated
/// gap values join the staged profile. A local result and status
/// make that two-step transaction explicit before the footer Save.
struct FitGapsAction: View {
    @ObservedObject var model: SettingsModel
    @State private var extraSpacing = 0
    @State private var appliedSignature: Signature?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            FitGapsSpacingRow(
                label: L(
                    "border.fit_gaps.extra_spacing",
                    "Extra spacing"
                ),
                value: $extraSpacing,
                in: spacingRange,
                suffix: L("border.fit_gaps.unit", "pt")
            )
            result
            Button(
                L(
                    "border.fit_gaps.action",
                    "Set Gap Values"
                )
            ) {
                setGapValues()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(gapsMatch)
            .help(actionHelp)
            .accessibilityHint(actionHelp)
        }
    }

    private var title: some View {
        HStack(spacing: 4) {
            Text(
                L(
                    "border.fit_gaps.title",
                    "Fit layout gaps"
                )
            )
            .fontWeight(.medium)
            HelpButton(
                explanation: L(
                    "border.fit_gaps.help",
                    "Calculates global outer and inner gaps "
                        + "from the border width. Inner gaps "
                        + "allow for both borders when borders "
                        + "on unfocused windows are shown."
                ),
                subject: L(
                    "border.fit_gaps.title",
                    "Fit layout gaps"
                )
            )
        }
    }

    @ViewBuilder private var result: some View {
        if actionWasApplied, model.isDirty {
            Label(appliedStatus, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel(appliedStatus)
        } else if gapsMatch {
            Label(
                L(
                    "border.fit_gaps.already_matches",
                    "Draft gaps already match."
                ),
                systemImage: "checkmark.circle"
            )
            .foregroundStyle(.secondary)
        } else {
            Text(resultPreview)
                .foregroundStyle(.secondary)
            if currentGapsAreAsymmetric {
                Label(
                    L(
                        "border.fit_gaps.replaces_edges",
                        "Replaces per-edge gap values."
                    ),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
        }
    }

    private var spacingRange: ClosedRange<Int> {
        let range = BorderStyle.remainingGapRange
        return Int(range.lowerBound)...Int(range.upperBound)
    }

    private var fittedGaps: Gaps {
        model.config.settings.borderStyle.fittingGaps(
            remaining: CGFloat(extraSpacing)
        )
    }

    private var gapsMatch: Bool {
        model.config.settings.gapsGlobal == fittedGaps
    }

    private var currentGapsAreAsymmetric: Bool {
        let gaps = model.config.settings.gapsGlobal
        let outer = gaps.outer
        let inner = gaps.inner
        return outer.top != outer.bottom
            || outer.top != outer.left
            || outer.top != outer.right
            || inner.horizontal != inner.vertical
    }

    private var resultPreview: String {
        L(
            "border.fit_gaps.preview",
            "Will set Outer to %1$d pt and Inner to %2$d pt.",
            Int(fittedGaps.outer.top),
            Int(fittedGaps.inner.horizontal)
        )
    }

    private var actionHelp: String {
        gapsMatch
            ? L(
                "border.fit_gaps.already_matches",
                "Draft gaps already match."
            )
            : L(
                "border.fit_gaps.action_hint",
                "Updates the draft gap values. Save is still "
                    + "required."
            )
    }

    private var appliedStatus: String {
        if let editing = model.editingProfile,
            editing != model.activeProfile
        {
            return L(
                "border.fit_gaps.updated_inactive",
                "Draft updated — Save (⌘S) to persist; it "
                    + "applies when this profile is loaded."
            )
        }
        if model.activeProfile == nil {
            return L(
                "border.fit_gaps.updated_new",
                "Draft updated — Save as New Profile… to "
                    + "apply and persist."
            )
        }
        return L(
            "border.fit_gaps.updated",
            "Draft updated — Save (⌘S) to apply and persist."
        )
    }

    private var actionWasApplied: Bool {
        appliedSignature == signature && gapsMatch
    }

    private var signature: Signature {
        Signature(gaps: fittedGaps, target: targetKey)
    }

    private var targetKey: String {
        if let editing = model.editingProfile {
            return "stored:\(editing)"
        }
        if let active = model.activeProfile {
            return "live:\(active)"
        }
        return "live:new"
    }

    private func setGapValues() {
        model.config.settings.gapsGlobal = fittedGaps
        appliedSignature = signature
        AccessibilityNotification.Announcement(appliedStatus)
            .post()
    }

    private struct Signature: Equatable {
        let gaps: Gaps
        let target: String
    }
}
