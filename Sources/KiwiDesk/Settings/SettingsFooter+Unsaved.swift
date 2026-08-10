import KiwiDeskCore
import SwiftUI

/// The pill's leading readout and the unsaved-changes popover
/// it opens (turn 9's third view of the draft, moved here from
/// the header chip — owner 2026-08-10). Split from
/// `SettingsFooter` when the popover took the file past the
/// §2.1 target: this half is the draft narration, the other is
/// the verbs, and they change for different reasons.
extension SettingsFooter {

    /// The pill's first words: the change count with the edit
    /// target's name, plus — stacked small beneath — whichever
    /// scope caption applies (#516 keeps the paused scope and
    /// the drift adoption VISIBLE, never a hover-only fact).
    /// While the draft has attributed rows the count line is a
    /// BUTTON opening the diff popover (`countButton`); at zero
    /// rows there is no list to open, so it stays plain text.
    ///
    /// The N is the ROW count of the very list the popover
    /// renders — one source, so the sentence and the list it
    /// opens cannot disagree. `draftChangeCount` counts distinct
    /// SETTINGS, and a per-instance family (three space modes
    /// changed = one census key, three rows) made the pill say
    /// "1" over a three-row list (owner, 2026-08-10).
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

    /// The count line as the popover's opener. Plain style on
    /// the pill's own ink — the pill is dark chrome in both
    /// modes, so the accent-label guards' bordered machinery
    /// has no business here; the chevron is what says
    /// "clickable" at rest, and hover confirms it with the
    /// pill-ink wash + pointing hand (owner 2026-08-10 — the
    /// search rows set the expectation). The shared
    /// `hoverHighlight` chip is `Color.primary`-based, which
    /// inverts with the appearance; on a pill that is dark in
    /// BOTH modes the wash must ride the fixed pill ink.
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

    /// The popover view of the one draft (turn 9): every change
    /// as a labelled old → new row, each a jump to the control
    /// that changed. It renders the SAME rows as the panel's
    /// diff list — one renderer, so the two views of the draft
    /// cannot disagree.
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
            // The docked footer's own key, kept through the
            // pill rewrite: identical English, same meaning
            // class, ten shipped translations (review
            // 2026-08-10 caught the re-mint discarding them).
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

    /// The banner above stays the authoritative naming of the
    /// edit target; this is the pill's short echo of it.
    private var editTargetName: String? {
        if model.editingLua { return "init.lua" }
        return model.editingProfile ?? model.activeProfile
    }
}

/// The count button's hover confirmation: the pill-ink wash and
/// the pointing hand. Not the shared `hoverHighlight` chip on
/// purpose — that one paints `Color.primary`, which flips with
/// the appearance, and this sits on chrome that is dark in both.
private struct PillHoverWash: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        // 0.14 eyeball-confirmed on the dark
                        // plate (owner 2026-08-10) — above the
                        // light-surface chips' 0.06/0.12
                        // ladder, below chalk.
                        SettingsTheme.savePillInk.opacity(
                            hovering ? 0.14 : 0
                        )
                    )
            )
            .padding(.horizontal, -6)
            .padding(.vertical, -3)
            .animation(
                .easeOut(duration: 0.12),
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
