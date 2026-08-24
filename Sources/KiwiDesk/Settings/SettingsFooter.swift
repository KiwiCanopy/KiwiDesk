import KiwiDeskCore
import SwiftUI

/// The floating save pill (#678 redesign spec): "N
/// unsaved changes to Desk | Revert · Save a copy… · Save",
/// dark chrome floating over the content column. It exists
/// only while there is something to act on — a dirty draft,
/// profile-level edits, or layout drift — and disappears at
/// zero (`GreyOutHidingTests` carries this file's exemption
/// from grey-don't-hide). Owner 2026-08-09 overturned the
/// earlier docked-footer ruling on sight — at 1440 the pill
/// costs 74 px of gutter and covers nothing.
///
/// Below the row breakpoint it docks (17a, `docked:`): the same
/// three verbs and the same count, in a full-width bar the
/// shell gives its own height, because at 820 pt the floating
/// version sits on top of the rows it is about. One view, two
/// physics — never a second footer type, which is how the two
/// would come to say different things about one draft.
///
/// The naming stays POSITIONAL in both forms (owner ruling
/// 2026-08-10, re-affirmed for this pass): no locale coins a
/// noun for it, so docking changes nothing a translator sees.
///
/// The verbs keep the docked footer's exact semantics per mode
/// (#68 §3.12):
/// - Live w/ active profile: Save = update the profile (+
///   monitor-set refresh); Copy = snapshot into a new profile.
/// - Stored-profile edit: Save = write that profile's JSON
///   without switching the layout; Copy = duplicate with the
///   pending edits (#82). A CLEAN duplicate no longer has a
///   footer to live in — that offer stays reachable from the
///   Profiles area, which is its home.
/// - Live w/ no profile: the primary becomes "Save as New
///   Profile…".
/// - Raw-Lua editing: Save writes init.lua verbatim.
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel
    /// The docked form (17a). A parameter rather than a read of
    /// `\.settingsWidth`: the shell decides WHERE this mounts —
    /// overlay or sibling — and a footer that answered the
    /// width itself could disagree with the container it is in.
    var docked = false
    @State var namingNewProfile = false
    @State var newProfileName = ""
    @State var namingProfileCopy = false
    @State var profileCopyName = ""
    /// The unsaved-changes popover — turn 9's third view of the
    /// draft, moved here from the header chip (owner
    /// 2026-08-10): the pill already narrates the draft, so the
    /// count it carries is the one that opens the list. View
    /// state: closing the window closes it, and nothing else
    /// needs to open it.
    @State var unsavedPopoverShown = false
    /// The pill's pending appearance announcement (#812) — held
    /// so leaving the dirty state inside the delay cancels it:
    /// a Save right after the edit must not hear "Unsaved
    /// changes" over a clean tree, and a re-flip inside the
    /// window must not stack a second post.
    @State private var pendingAnnouncement: DispatchWorkItem?

    /// How long the pill's appearance announcement waits for the
    /// changed control's own value to be spoken first.
    static let announceDelay: TimeInterval = 1.2

    /// Anything that gives a verb meaning. The
    /// `.saveAsNewProfile` creation offer on a fully clean
    /// setup deliberately does NOT summon the pill — creation
    /// lives in Profiles; the pill narrates a draft.
    private var hasWork: Bool {
        model.isDirty || model.profileDirty
            || model.hasLayoutDrift
    }

    var body: some View {
        Group {
            if hasWork {
                bar
                    .transition(
                        .opacity.combined(
                            with: .move(edge: .bottom)
                        )
                    )
            }
        }
        // The pill is last in reading order on both mounts — an
        // overlay after the content, or the sibling below it —
        // so a VoiceOver user editing a row never reaches it and
        // would never learn a Save is pending. Announce ONCE, as
        // the pill appears, and never the count (owner ruling,
        // #812 session 2: native macOS narrates no dirty state,
        // and a count per change is noise — it is one VO-cursor
        // move to the pill away). Delayed, because posted in the
        // same instant as the control's own value ("7 pt") the
        // announcement was dropped on device under keyboard
        // stepping; the delay lets the value finish first.
        // Silent on the way out: Save and Discard say their own
        // outcome, so the flip to false cancels the pending
        // post rather than letting it land on a clean tree.
        .onChange(of: hasWork) { _, now in
            pendingAnnouncement?.cancel()
            guard now else { return }
            let sentence = appearanceSentence
            let work = DispatchWorkItem {
                AccessibilityNotification.Announcement(sentence)
                    .post()
            }
            pendingAnnouncement = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Self.announceDelay,
                execute: work
            )
        }
        .alert(
            L(
                "footer.save_as_new.title",
                "Save as new profile"
            ),
            isPresented: $namingNewProfile
        ) {
            TextField(
                L("footer.profile_name", "Profile name"),
                text: $newProfileName
            )
            Button(L("footer.save", "Save")) {
                model.saveAsNewProfile(named: newProfileName)
                newProfileName = ""
            }
            .disabled(newProfileName.trimmed.isEmpty)
            Button(L("footer.cancel", "Cancel"), role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(saveAsNewMessage)
        }
        .alert(
            L("footer.save_copy_as.title", "Save as new profile"),
            isPresented: $namingProfileCopy
        ) {
            TextField(
                L("footer.profile_name", "Profile name"),
                text: $profileCopyName
            )
            Button(L("footer.save_copy", "Save copy")) {
                model.saveEditedProfileCopy(
                    named: profileCopyName
                )
                profileCopyName = ""
            }
            .disabled(profileCopyName.trimmed.isEmpty)
            Button(L("footer.cancel", "Cancel"), role: .cancel) {
                profileCopyName = ""
            }
        } message: {
            Text(saveCopyMessage)
        }
    }

    /// The verbs, identical in both forms — only the container
    /// under them changes.
    private var verbs: some View {
        HStack(spacing: 12) {
            leadingReadout
            Text(verbatim: "|")
                .foregroundStyle(
                    SettingsTheme.savePillInk.opacity(0.4)
                )
            Button(L("footer.revert", "Revert")) {
                model.revert()
            }
            .buttonStyle(.plain)
            .foregroundStyle(
                SettingsTheme.savePillInk.opacity(0.8)
            )
            .disabled(!(model.isDirty || model.hasLayoutDrift))
            copySlot
            primarySlot
        }
        .font(.callout)
    }

    @ViewBuilder private var bar: some View {
        if docked { dockedBar } else { pill }
    }

    private var pill: some View {
        verbs
            .padding(.leading, 18)
            .padding(.trailing, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .fill(SettingsTheme.savePill)
                .shadow(
                    color: SettingsTheme.savePill.opacity(0.45),
                    radius: 17,
                    y: 7
                )
            )
            // The 16b dark construction: the self-coloured
            // shadow above is the pill's lift in light and is
            // invisible in dark, where the fill sits within
            // ~1.1:1 of the page — there the inset light line
            // is the edge.
            .overlay(
                RoundedRectangle(
                    cornerRadius: SettingsTheme.cardRadius
                )
                .strokeBorder(
                    SettingsTheme.planeRing,
                    lineWidth: 1
                )
            )
    }

    /// The docked form: full width, square, and trailing-aligned
    /// so the primary verb keeps the corner the pill's did. No
    /// shadow — a bar the window's own edge terminates is not a
    /// floating object, and the lift that reads as elevation on
    /// a pill reads as a smear along a full-width edge.
    private var dockedBar: some View {
        VStack(spacing: 0) {
            // The same seam the pill's ring is: this fixed-dark
            // plane meets the mode-varying page above it, and in
            // dark the fill sits within ~1.1:1 of that page.
            SettingsTheme.planeRing.frame(height: 1)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                verbs
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(SettingsTheme.savePill)
        }
    }

    private var saveAsNewMessage: String {
        L(
            "footer.save_as_new.message",
            "The new profile carries the current tiling "
                + "and the connected monitor set."
        )
    }

    private var saveCopyMessage: String {
        L(
            "footer.save_copy_as.message",
            "Duplicates \u{201C}%1$@\u{201D} with your "
                + "pending edits — monitor sets and shortcut "
                + "overrides included. The copy becomes the "
                + "edit target; the running layout is not "
                + "changed.",
            model.editingProfile ?? ""
        )
    }
}
