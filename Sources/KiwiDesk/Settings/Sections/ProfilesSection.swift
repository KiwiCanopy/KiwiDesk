import KiwiDeskCore
import SwiftUI

/// Whole App ▸ Profiles (#36/#53/#68 §3.2, rebuilt in #678
/// Phase 3 turn 13a): what a profile IS, which ones exist, which
/// one loads, and where to start from nothing — in that order.
///
/// The list is flat now. It used to group by screen count with a
/// header per count and a chip row of raw monitor names per row,
/// which spent the whole row on the machine and left the user to
/// infer what the profile contained. The subtitle counts what the
/// profile OWNS instead — screens, spaces, shortcut overrides —
/// and the screen count keeps the monitor names as its tooltip.
///
/// The lead-in text is the AREA's caption. The interim sidebar
/// shell has no area header to hang it on (Home, the last Phase 3
/// lane, is what grows one), so it renders as the pane's first
/// line rather than being dropped until then — the sentence is
/// the answer to "what is a profile", which is the question this
/// page opens with.
struct ProfilesSection: View {
    @ObservedObject var model: SettingsModel
    /// The profile whose rename popover is open, if any.
    /// `internal`, not `private`: the rename affordance that
    /// owns this state lives in `ProfilesSection+Rename.swift`
    /// (file ceiling), and `@State` cannot move to an extension.
    /// The rename popover's presentation, carrying the seed it
    /// opens with (#843) — never a flag plus a separately
    /// written draft, which the confirm button read as empty.
    @State var renameRequest: NameEditRequest?
    /// Where the keyboard lands after a row stops existing
    /// (#816). Keyed by profile NAME across both lists — a
    /// profile is either loaded or broken, never in both, so one
    /// key cannot be claimed by two rows. `internal` for the
    /// same reason the rename state is: the rows that bind it
    /// live in extensions, and `@FocusState` cannot move there.
    @FocusState var returningRow: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(areaCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.profileSummaries.isEmpty {
                    // Bootstrap: with nothing saved, the presets
                    // are the only thing on this page that can be
                    // acted on, so they lead (#53).
                    PresetsSection(model: model)
                    profileSection
                    whichProfileLoads
                    NativeSpacesGroup(model: model)
                } else {
                    profileSection
                    whichProfileLoads
                    NativeSpacesGroup(model: model)
                    PresetsSection(model: model)
                }
            }
            .animation(
                .default,
                value: model.profileSummaries.isEmpty
            )
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var areaCaption: String {
        L(
            "profiles.area.caption",
            "A profile is your whole setup, remembered per "
                + "display arrangement."
        )
    }

    // MARK: - Your profiles (#36)

    private var profileSection: some View {
        SettingsSection(
            SettingsCatalog.profiles.savedProfiles,
            caption: L(
                "profiles.saved.caption",
                "The one matching your displays loads "
                    + "automatically."
            )
        ) {
            if model.profileSummaries.isEmpty
                && model.brokenProfiles.isEmpty
            {
                Text(noProfilesCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(orderedSummaries) { summary in
                profileRow(summary)
            }
            if let note = currentSetupNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            if !model.brokenProfiles.isEmpty {
                brokenGroup
            }
        }
    }

    /// "a built-in layout", not "the built-in Standard": no
    /// layout is NAMED Standard — the ones that resolve silently
    /// are Developer, Dual Developer and Command Center, and the
    /// card below this one names whichever is live. Two
    /// paragraphs of one page calling the same thing by two
    /// nouns is what sends a translator two ways.
    private var noProfilesCaption: String {
        L(
            "profiles.saved.empty",
            "No profiles saved yet — a built-in layout "
                + "resolves until you save one."
        )
    }

    /// Where the live edits land, and how to keep them apart —
    /// the question a user asks the moment they realise editing
    /// anything writes into the profile that is loaded.
    private var currentSetupNote: String? {
        guard !model.editingStoredProfile,
            let active = model.activeProfile
        else { return nil }
        // The button's own label, INTERPOLATED rather than
        // re-typed (#818) — a note that names a control by an
        // approximation sends the reader looking for something
        // that is not there, and this one had already drifted:
        // it said "Save a Copy As…" while the button says
        // "Save a copy…". A literal quotation is a mirror every
        // locale then has to keep in step with nothing checking
        // that it does.
        return L(
            "profiles.current_setup_note",
            "Your current setup is saved into %1$@. To keep it "
                + "separately, use \u{201C}%2$@\u{201D} in the "
                + "bar below.",
            active,
            L("footer.save_a_copy_as", "Save as new profile…")
        )
    }

    /// The saved-profile rows, in display order — from the
    /// family seam's own derivation, which is what the census
    /// guards read too.
    private var orderedSummaries: [ProfileSummary] {
        ProfilesFamilyRows.orderedProfiles(
            model.profileSummaries
        )
    }

    /// This list's display order, handed to the shared rule
    /// (`DeletionFocus`) — which order it is IS this call site's
    /// contribution; the stepping is not.
    func neighbourAfterDeleting(_ name: String) -> String? {
        DeletionFocus.neighbour(
            after: name,
            in: orderedSummaries.map(\.name)
        )
    }

    private func profileRow(
        _ summary: ProfileSummary
    ) -> some View {
        // CENTRED, not first-text-baseline: the picture belongs
        // to the whole row — the name AND the subtitle counting
        // the screens it draws — so pinning it to the title's
        // baseline sat it high against a two-line block and read
        // as belonging to the first line only (owner eye-confirm,
        // 2026-08-16). It is also what the design prototype's own
        // row does (`align-items:center`), and it carries the
        // buttons with it, which is the same arrangement there.
        //
        // Centring is what RETIRED an `.alignmentGuide` here: a
        // picture with no text baseline resolves to its own bottom
        // edge, so under baseline alignment a row whose picture
        // carried a "+N" chip seated differently from one whose
        // did not. With no baseline in the alignment there is
        // nothing to correct.
        HStack(alignment: .center) {
            // The screen count as a picture (#789), replacing a
            // glyph that was identical on every row and so
            // distinguished none of them. The tooltip stays on
            // the subtitle below rather than moving here: `.help`
            // on a decorative image is hover-only, and this one
            // is `.accessibilityHidden`.
            screenPicture(summary)
            VStack(alignment: .leading, spacing: 3) {
                rowTitle(summary)
                Text(subtitle(summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help(monitorTooltip(summary))
            }
            Spacer()
            if !summary.isDefault {
                makeDefaultLink(summary.name)
            }
            loadButton(summary)
            deleteButton(summary.name)
        }
    }

    /// The row's leading picture — one outline per screen in the
    /// same grammar the preset cards draw, so the two surfaces
    /// answer "what shape is this profile" one way (#789).
    private func screenPicture(
        _ summary: ProfileSummary
    ) -> some View {
        ProfileScreenPips(
            count: summary.count,
            openingModes: summary.openingModes,
            reservedSlots: reservedScreenSlots
        )
    }

    /// The width every row's picture reserves — the widest
    /// profile in THIS list, so the names align without a
    /// one-screen list paying for four screens' worth of gap.
    private var reservedScreenSlots: Int {
        ProfileScreenPips.reservedSlots(
            forScreenCounts: orderedSummaries.map(\.count)
        )
    }

    private func rowTitle(
        _ summary: ProfileSummary
    ) -> some View {
        HStack(spacing: 6) {
            Text(summary.name)
                // Bonus discovery path (low-risk): a double-click
                // on the name opens the same rename popover as
                // the pencil, which stays the primary visible cue.
                .onTapGesture(count: 2) {
                    beginRename(summary.name)
                }
            renameButton(summary.name)
            if summary.name == model.activeProfile {
                BadgeChip(
                    label: L("profiles.badge.active", "active")
                )
            }
            if summary.isDefault {
                BadgeChip(
                    label: L("profiles.badge.default", "default")
                )
                duplicateDefaultWarning(summary)
            }
        }
    }

    /// Several profiles of one screen count marked default is a
    /// hand-edited-file state, so the warning rides the rows it
    /// is about rather than a count header the flat list no
    /// longer has.
    @ViewBuilder private func duplicateDefaultWarning(
        _ summary: ProfileSummary
    ) -> some View {
        if model.duplicateDefaultCounts.contains(summary.count) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(SettingsTheme.warningInk)
                .font(.caption)
                .help(
                    L(
                        "profiles.duplicate_default.help",
                        "Several profiles of this count "
                            + "are marked default; the "
                            + "alphabetically first wins."
                    )
                )
        }
    }
}
