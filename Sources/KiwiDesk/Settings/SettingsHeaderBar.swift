import KiwiDeskCore
import SwiftUI

/// The one header bar (#678 turn 9): on Home the app identity,
/// on an area screen the "← Home" back chip and the area title —
/// followed either way by the same search entry, profile chip,
/// Simple|Power User segment and, while the draft has changes, the
/// unsaved-changes count. The status sentence and profile
/// warning ride a second row exactly as the old header drew
/// them. One bar for both screens so the chrome reads as
/// continuous across push and pop.
struct SettingsHeaderBar: View {
    @ObservedObject var model: SettingsModel
    /// Focuses the back chip when an area is pushed (turn 20:
    /// every shape change names a focus destination).
    @FocusState private var backChipFocused: Bool
    /// Passed into `flipSettingsMode` so the reveal timeline's
    /// hold can absorb the fade it drops (#760) — the model has
    /// no environment of its own.
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    /// The unsaved-changes popover (turn 9's third view of the
    /// draft). View state: closing the window closes it, and
    /// nothing else needs to open it.
    @State private var unsavedPopoverShown = false

    private var destination: SettingsDestination? {
        model.destination
    }

    private var showsProfileContext: Bool {
        destination?.showsProfileContext ?? true
    }

    @ViewBuilder var body: some View {
        VStack(spacing: 0) {
            rows
                // Above the hairline SIBLING below, so the
                // search overlay hanging off `titleRow` paints
                // OVER the header separator instead of the
                // separator crossing the result panel (owner,
                // 2026-08-10) — the one line that survived the
                // panel's compositing fix was this one, drawn
                // after the overlay inside the same lifted
                // header composite.
                .zIndex(1)
            SettingsTheme.hairline.frame(height: 1)
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 6) {
            titleRow
            if showsProfileContext {
                if let status = statusText {
                    statusRow(status)
                }
                if let warning = model.profileWarning {
                    warningRow(warning)
                }
            }
        }
        // NO container-level `.foregroundStyle` here, and that is
        // a rule rather than an omission: `.secondary` and
        // `.tertiary` are HIERARCHICAL styles, derived from the
        // enclosing foreground rather than from a fixed grey. Set
        // `ink` on the bar and every `.secondary` beneath it —
        // including inside `ProfileEditTargetMenu`, which this
        // file does not own — becomes a translucent dark GREEN,
        // and green-on-green is what the header actually rendered
        // (owner, 2026-08-04). Each Text names its own ink.
        .padding(.horizontal, 16)
        // Clears the traffic-light row — `SettingsView`'s
        // `ignoresSafeArea(.top)` discards the titlebar inset
        // that would otherwise size this, so it's a fixed
        // constant matched to the unified-titlebar height. This
        // is the known-fragile point if Apple changes that
        // metric (a visual break the verify gate can't catch).
        //
        // Which is now a SMALL constant, because the row sits
        // BESIDE the lights rather than under them (owner,
        // 2026-08-04) — `titleRow` buys its clearance
        // horizontally instead, and stacking the two put the app
        // mark directly beneath the close button, which reads as
        // an accident rather than as a second row. The bottom
        // padding grew in the same pass: the bar was reading as a
        // strip rather than as the 64 pt header the prototype
        // draws.
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Opaque Card fill, not `.bar` (owner ruled fully opaque,
        // 2026-08-04). The vibrancy tracked whatever sat behind
        // the window, so the header was the one surface in the
        // shell whose colour the app did not choose — the single
        // biggest "wrong colour" report on the shipped shell.
        .background(SettingsTheme.card)
        .onChange(of: destination != nil) { _, pushed in
            if pushed { backChipFocused = true }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            if let destination {
                backChip
                // NO `layoutPriority` on the title: at the 720 pt
                // hard minimum something in this row has to give,
                // and the order must be search field down to its
                // floor, then the TITLE truncates — never a chip
                // or the segment clipped. A priority here inverts
                // that and drops a control, which the responsive
                // rule forbids ("controls never", 17a).
                Text(destination.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SettingsTheme.ink)
                    .lineLimit(1)
            } else {
                identity
            }
            // No `Spacer` here on purpose: the search field is
            // the flexible element, so it fills the middle and
            // the chips cluster at the trailing edge instead of
            // being flung to the window's corner.
            HeaderSearch(
                context: searchContext,
                spotlightProfiles:
                    model.profileSummaries.isEmpty,
                value: { [weak model] key in
                    model?.searchValue(for: key)
                },
                reveal: { model.nav.pendingReveal = $0 },
                armModeNotice: { model.nav.pendingModeNotice = $0 }
            )
            if showsProfileContext {
                profileChip
            }
            modeSegment
            if model.draftChangeCount > 0 {
                unsavedChip
            }
        }
        // Clears the three traffic lights, which AppKit places at
        // a fixed offset from the window's leading edge whatever
        // this view does. Spent on THIS row alone: the status
        // sentence and profile warning below it sit under the
        // lights, so they keep the bar's ordinary 16 pt gutter
        // and stay aligned with the content column.
        .padding(.leading, SettingsHeaderBar.trafficLightInset)
    }

    /// "← [mark] Home", the area screen's one way back — beside
    /// ⌘[ and the Escape route the shell owns.
    private var backChip: some View {
        Button {
            model.destination = nil
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 11, weight: .semibold))
                if let mark = BrandAssets.appMark {
                    Image(nsImage: mark)
                        .resizable()
                        .scaledToFit()
                        // 22 over the inventory's 18, tracking
                        // the identity mark's own bump.
                        .frame(width: 22, height: 22)
                }
                Text(L("home.back", "Home"))
                    .font(.callout)
            }
            .foregroundStyle(SettingsTheme.ink)
            .chipSurface()
            .contentShape(ChipMetrics.shape)
        }
        .buttonStyle(.plain)
        .focused($backChipFocused)
        .keyboardShortcut("[", modifiers: .command)
        .accessibilityLabel(L("home.back", "Home"))
    }

    /// The edit-target dropdown, restyled as a header chip — the
    /// same menu, so #18/#209 behavior is untouched. The accent
    /// dot is the prototype's: it marks WHICH chip in the row
    /// carries the profile, since a filled chip alone no longer
    /// distinguishes it from the back chip beside it.
    private var profileChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SettingsTheme.accent)
                .frame(width: 8, height: 8)
            ProfileEditTargetMenu(model: model)
        }
        .chipSurface()
    }

    private var modeSegment: some View {
        Picker(
            L("home.mode_ax", "Settings mode"),
            selection: Binding(
                get: { model.settingsMode },
                // The EXPLICIT flip — the one entry point that
                // washes what the flip inserts (#760).
                set: {
                    model.flipSettingsMode(
                        $0,
                        reduceMotion: reduceMotion
                    )
                }
            )
        ) {
            Text(L("mode.simple", "Simple"))
                .tag(SettingsMode.simple)
            // The site's slider keeps its own "Nerd" flair —
            // different surface, different register (owner
            // 2026-08-04; docs/localization-naming.md).
            Text(L("mode.power_user", "Power User"))
                .tag(SettingsMode.powerUser)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(L("home.mode_ax", "Settings mode"))
    }

    /// The count view of the one draft (turn 9) — a BUTTON now:
    /// the Phase 4 readout gave diff rows their label authority
    /// (`SettingsValueReadout` narrates every attributed key,
    /// and the attribution net is total), so the popover lists
    /// the whole draft and the earlier partial-list objection
    /// is discharged. Save and Revert stay in the pill.
    ///
    /// Neutral ink on a bordered chip with an amber DOT, not
    /// amber text on an amber outline: unsaved work is a state,
    /// not a fault, and the paused banner below owns the amber
    /// that means something is wrong. The dot keeps the warning
    /// hue where it is cheap and the sentence readable.
    private var unsavedChip: some View {
        Button {
            unsavedPopoverShown = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(SettingsTheme.warningInk)
                    .frame(width: 8, height: 8)
                // Truncates rather than holding the row open:
                // this is the row's longest element in every
                // locale ("12 nicht gespeicherte Änderungen" is
                // ~218 pt) and the only one that is not a fixed
                // control. At the 720 pt minimum something has
                // to give, and a clipped segmented control is
                // the outcome 17a forbids. The dot survives
                // truncation; the full sentence is in `.help`.
                Text(unsavedText)
                    .font(.caption)
                    .foregroundStyle(SettingsTheme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, ChipMetrics.padH)
            .padding(.vertical, ChipMetrics.padV)
            .background(
                ChipMetrics.shape
                    .fill(SettingsTheme.card)
                    .overlay(
                        ChipMetrics.shape.strokeBorder(
                            SettingsTheme.hairline
                        )
                    )
            )
            .contentShape(ChipMetrics.shape)
        }
        .buttonStyle(.plain)
        .help(
            L(
                "home.unsaved.help",
                "Changes not saved yet — click for the list; "
                    + "Save and Revert are in the save pill."
            )
        )
        .popover(
            isPresented: $unsavedPopoverShown,
            arrowEdge: .bottom
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

    /// Singular has its own frame — "1 unsaved changes" is not
    /// a plural rule any locale can fix from one key.
    private var unsavedText: String {
        guard model.draftChangeCount > 1 else {
            return L(
                "home.unsaved.count_one",
                "1 unsaved change"
            )
        }
        return L(
            "home.unsaved.count",
            "%1$d unsaved changes",
            model.draftChangeCount
        )
    }
}
