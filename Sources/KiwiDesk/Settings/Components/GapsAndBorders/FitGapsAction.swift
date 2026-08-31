import Accessibility
import KiwiDeskCore
import SwiftUI

/// Focus Border gap transformation action controls (#295).
struct FitGapsAction: View {
    @ObservedObject var model: SettingsModel
    @State private var extraSpacing = 0
    @State private var appliedSignature: Signature?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            title
            StepperRow(
                label: L(
                    "border.fit_gaps.extra_spacing",
                    "Extra spacing"
                ),
                value: $extraSpacing,
                in: spacingRange,
                suffix: L("border.fit_gaps.unit", "pt"),
                liveCommit: true
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
            .settingsActionButton()
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
                .foregroundStyle(SettingsTheme.groupHeading)
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
                .foregroundStyle(SettingsTheme.warningInk)
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
                "Updates the draft gap values. %1$@ is still "
                    + "required.",
                L("footer.save", "Save")
            )
    }

    /// Reads `model.primarySaveAction` — the same classifier the
    /// footer's primary slot uses — so the "press Save" hint can
    /// never point at a verb the footer isn't showing.
    private var appliedStatus: String {
        switch model.primarySaveAction {
        case .updateStoredProfile:
            return L(
                "border.fit_gaps.updated_inactive",
                "Draft updated — %1$@ (⌘S) to persist; it "
                    + "applies when this profile is loaded.",
                L("footer.save", "Save")
            )
        case .saveAsNewProfile:
            return L(
                "border.fit_gaps.updated_new",
                "Draft updated — %1$@ to apply and persist.",
                L(
                    "footer.save_as_new_profile",
                    "Save as New Profile…"
                )
            )
        case .saveGlobalsOnly:
            // Paused: Save writes gui.json only, and gaps are
            // tiling — so this draft is NOT what that Save
            // persists. Say so rather than pointing at a verb
            // that won't carry it (#516).
            return L(
                "border.fit_gaps.updated_paused",
                "Draft updated — gaps persist once "
                    + "Accessibility is on and you save the "
                    + "profile."
            )
        case .updateActiveProfile, .saveLua:
            return L(
                "border.fit_gaps.updated",
                "Draft updated — %1$@ (⌘S) to apply and persist.",
                L("footer.save", "Save")
            )
        }
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
