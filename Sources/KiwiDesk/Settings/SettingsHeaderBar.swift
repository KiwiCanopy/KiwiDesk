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

    private var destination: SettingsDestination? {
        model.destination
    }

    private var showsProfileContext: Bool {
        destination?.showsProfileContext ?? true
    }

    @ViewBuilder var body: some View {
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
        SettingsTheme.hairline.frame(height: 1)
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
                editingStoredProfile:
                    model.editingStoredProfile,
                spotlightProfiles:
                    model.profileSummaries.isEmpty,
                reveal: { model.nav.pendingReveal = $0 }
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

    /// 100 − the bar's own 16 pt gutter.
    ///
    /// The third light's trailing edge falls at about 78 pt on a
    /// standard macOS titlebar (observed 2026-08-04, macOS 26),
    /// and starting the row THERE is what the first cut did: the
    /// app mark ended up 4 pt from the green button, touching it.
    /// 100 buys the mark the same air the prototype gives it.
    /// Neither number is published by any API, so this is a look
    /// constant like the top padding above and breaks the same
    /// silent way if Apple moves the buttons.
    private static let trafficLightInset: CGFloat = 84

    /// Home's identity: the mark beside "Settings" — decorative
    /// pair, one accessibility element.
    ///
    /// 26 pt, over the §3 inventory's 22: the mark is the app's
    /// one piece of identity on this screen and read as
    /// undersized against the taller bar (owner, 2026-08-04).
    private var identity: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            }
            Text(L("home.title", "Settings"))
                .font(.title2.weight(.bold))
                .foregroundStyle(SettingsTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L("home.title_ax", "KiwiDesk Settings")
        )
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
                set: { model.setSettingsMode($0) }
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

    /// The count view of the one draft (turn 9). A LABEL, not a
    /// button: the per-row diff popover ships with the Phase 4
    /// renderer work, and a count that opened a partial list
    /// would claim the list is the whole draft. Save and Revert
    /// stay in the footer.
    ///
    /// Neutral ink on a bordered chip with an amber DOT, not
    /// amber text on an amber outline: unsaved work is a state,
    /// not a fault, and the paused banner below owns the amber
    /// that means something is wrong. The dot keeps the warning
    /// hue where it is cheap and the sentence readable.
    private var unsavedChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SettingsTheme.warningInk)
                .frame(width: 8, height: 8)
            Text(unsavedText)
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink)
        }
        .padding(.horizontal, ChipMetrics.padH)
        .padding(.vertical, ChipMetrics.padV)
        .background(
            ChipMetrics.shape
                .fill(SettingsTheme.card)
                .overlay(
                    ChipMetrics.shape.strokeBorder(SettingsTheme.hairline)
                )
        )
        .help(
            L(
                "home.unsaved.help",
                "Changes not saved yet — Save and Revert "
                    + "are in the footer."
            )
        )
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
