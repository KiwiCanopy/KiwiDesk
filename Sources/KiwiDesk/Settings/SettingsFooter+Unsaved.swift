import KiwiDeskCore
import SwiftUI

/// Leading readout and unsaved-changes diff popover for `SettingsFooter`
/// (#516, `SettingsDiffRowSource`).
extension SettingsFooter {
    /// Readout displaying change count and drift/scope captions
    /// (#516 keeps them visible, never hover-only). The N is the
    /// ROW count of the very list the popover renders — one
    /// source: `draftChangeCount` counts distinct settings, and a
    /// per-instance family made the pill say "1" over a three-row
    /// list (owner 2026-08-10).
    var leadingReadout: some View {
        let rows = SettingsDiffRowSource.rows(for: model)
        return VStack(alignment: .leading, spacing: 2) {
            if !rows.isEmpty {
                countButton(count: rows.count)
            } else {
                Text(countLine(count: 0))
                    .foregroundStyle(SettingsTheme.savePillInk)
            }
            if model.primarySaveAction == .saveGlobalsOnly {
                caption(pausedScopeCaption)
            }
            if let drift = model.layoutDrift {
                caption(
                    L(
                        "footer.save.adopts_layout",
                        "Save also adopts the session layout "
                            + "(%1$@).",
                        drift.live.displayName
                    )
                )
                caption(
                    L(
                        "footer.revert.restores_layout",
                        "Revert also restores the profile "
                            + "layout (%1$@).",
                        drift.saved.displayName
                    )
                )
            }
        }
    }

    /// Button opening the unsaved-changes popover.
    private func countButton(count: Int) -> some View {
        Button {
            unsavedPopoverShown = true
        } label: {
            HStack(spacing: 5) {
                Text(countLine(count: count))
                    .foregroundStyle(SettingsTheme.savePillInk)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        SettingsTheme.savePillInk.opacity(0.65)
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pillHoverWash()
        .help(
            L(
                "footer.unsaved.help",
                "Click for the list of changes."
            )
        )
        .popover(
            isPresented: $unsavedPopoverShown,
            arrowEdge: .top
        ) {
            unsavedPopover
        }
    }

    /// Popover listing individual uncommitted setting diffs
    /// (`SettingsDiffJump`).
    private var unsavedPopover: some View {
        ScrollView {
            SettingsDiffRowsView(
                rows: SettingsDiffRowSource.rows(for: model)
            ) { row in
                unsavedPopoverShown = false
                guard
                    let anchor = SettingsDiffJump.anchor(
                        for: row
                    )
                else { return }
                model.nav.pendingReveal = anchor
            }
            .padding(14)
        }
        .frame(width: 340)
        .frame(maxHeight: 360)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.65)
            )
    }

    func countLine(count: Int) -> String {
        guard count > 0 else {
            // The docked footer's own key, kept through the pill
            // rewrite: identical English, ten shipped translations
            // (review 2026-08-10 caught the re-mint discarding
            // them).
            return L(
                "footer.unsaved_changes",
                "Unsaved changes"
            )
        }
        if let target = editTargetName {
            return count == 1
                ? L(
                    "footer.unsaved.count_one_to",
                    "%1$d unsaved change to %2$@",
                    count,
                    target
                )
                : L(
                    "footer.unsaved.count_to",
                    "%1$d unsaved changes to %2$@",
                    count,
                    target
                )
        }
        return count == 1
            ? L(
                "footer.unsaved.count_one",
                "%1$d unsaved change",
                count
            )
            : L(
                "footer.unsaved.count",
                "%1$d unsaved changes",
                count
            )
    }

    /// Spoken VoiceOver description when pill appears (#812).
    var appearanceSentence: String {
        guard let target = editTargetName else {
            return countLine(count: 0)
        }
        return L(
            "footer.unsaved.to",
            "Unsaved changes to %1$@",
            target
        )
    }

    private var editTargetName: String? {
        if model.editingLua { return "init.lua" }
        return model.editingProfile ?? model.activeProfile
    }
}

/// Hover highlight on pill dark chrome (#1069).
private struct PillHoverWash: ViewModifier {
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        SettingsTheme.savePillInk.opacity(
                            hovering ? 0.14 : 0
                        )
                    )
            )
            .padding(.horizontal, -6)
            .padding(.vertical, -3)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
            .onHover { hovering = $0 }
            .pointingHandCursor()
    }
}

extension View {
    fileprivate func pillHoverWash() -> some View {
        modifier(PillHoverWash())
    }
}
