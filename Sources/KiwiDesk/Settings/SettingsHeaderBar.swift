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
        .padding(.horizontal, 16)
        // Clears the traffic-light row — `SettingsView`'s
        // `ignoresSafeArea(.top)` discards the titlebar inset
        // that would otherwise size this, so it's a fixed
        // constant matched to the unified-titlebar height. This
        // is the known-fragile point if Apple changes that
        // metric (a visual break the verify gate can't catch).
        .padding(.top, 32)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .onChange(of: destination != nil) { _, pushed in
            if pushed { backChipFocused = true }
        }
        Divider()
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            if let destination {
                backChip
                Text(destination.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
            } else {
                identity
            }
            Spacer(minLength: 12)
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
    }

    /// Home's identity: the mark at 22 pt beside "Settings" —
    /// decorative pair, one accessibility element.
    private var identity: some View {
        HStack(spacing: 8) {
            if let mark = BrandAssets.appMark {
                Image(nsImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            Text(L("home.title", "Settings"))
                .font(.title2.weight(.bold))
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
                        .frame(width: 18, height: 18)
                }
                Text(L("home.back", "Home"))
                    .font(.callout)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(0.18)
                    )
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .focused($backChipFocused)
        .keyboardShortcut("[", modifiers: .command)
        .accessibilityLabel(L("home.back", "Home"))
    }

    /// The edit-target dropdown, restyled as a header capsule —
    /// the same menu, so #18/#209 behavior is untouched.
    private var profileChip: some View {
        ProfileEditTargetMenu(model: model)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(0.18)
                    )
            )
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
    private var unsavedChip: some View {
        Label(
            unsavedText,
            systemImage: "pencil.circle"
        )
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .strokeBorder(Color.orange.opacity(0.4))
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

    // MARK: - Status row (carried from the old header)

    private var showDivergence: Bool {
        model.profileDirty && !model.editingStoredProfile
    }

    private func statusRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            if showDivergence {
                Image(
                    systemName: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(
                    showDivergence ? .orange : .secondary
                )
            Spacer()
        }
    }

    private func warningRow(_ warning: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(.orange)
            Text(warning)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.profileWarning = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L("profile_header.dismiss", "Dismiss")
            )
        }
    }

    private var statusText: String? {
        if model.editingStoredProfile {
            // Editing the loaded profile's own overrides DOES
            // hit the screen — saving re-applies it in place
            // (#209) — so the generic "won't switch" copy is
            // false for that one target.
            if let name = model.editingProfile,
                name == model.activeProfile
            {
                return L(
                    "profile_header.status.editing_loaded",
                    "Editing %1$@'s saved overrides — saving "
                        + "re-applies %1$@ with your changes.",
                    name
                )
            }
            return L(
                "profile_header.status.editing_stored",
                "Editing a saved profile — changes won't "
                    + "switch your layout."
            )
        }
        if model.activeStandard != nil {
            return L(
                "profile_header.status.built_in",
                "Built-in layout — save as a profile to "
                    + "make it yours."
            )
        }
        if model.profileDirty {
            return L(
                "profile_header.status.unsaved_monitor",
                "Unsaved monitor changes — update the "
                    + "profile to keep them."
            )
        }
        if model.activeProfile == nil {
            return L(
                "profile_header.status.no_match",
                "No profile matches this monitor setup."
            )
        }
        return nil
    }
}
