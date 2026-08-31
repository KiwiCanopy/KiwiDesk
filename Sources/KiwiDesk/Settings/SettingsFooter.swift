import KiwiDeskCore
import SwiftUI

/// Floating save pill and docked footer bar for pending changes
/// (#678, #68 §3.12, #82).
/// Excluded from grey-don't-hide rule (`GreyOutHidingTests`;
/// Owner 2026-08-09, 2026-08-10).
struct SettingsFooter: View {
    @ObservedObject var model: SettingsModel
    /// Renders docked bar when true (17a).
    var docked = false
    @State var namingNewProfile = false
    @State var newProfileName = ""
    @State var namingProfileCopy = false
    @State var profileCopyName = ""
    /// Unsaved changes popover state (owner 2026-08-10).
    @State var unsavedPopoverShown = false
    /// Delayed VoiceOver appearance announcement (#812).
    @State private var pendingAnnouncement: DispatchWorkItem?

    /// VoiceOver announcement delay before speaking (#812).
    static let announceDelay: TimeInterval = 1.2

    /// Anything that gives a verb meaning. The creation offer on
    /// a fully clean setup deliberately does NOT summon the pill —
    /// creation lives in Profiles; the pill narrates a draft.
    private var hasWork: Bool {
        model.isDirty || model.profileDirty
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
        // Announce ONCE as the pill appears, never the count
        // (owner ruling, #812 session 2) — the pill is last in
        // reading order, so an editing VoiceOver user would never
        // learn a Save is pending. Delayed: posted in the same
        // instant as the control's own value it was dropped on
        // device. The flip to false cancels the pending post so
        // it cannot land on a clean tree.
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
            // Interpolated as verb in de/ja/ko frames
            // (localization audit, 2026-08-29).
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
            .disabled(!model.isDirty)
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

    private var dockedBar: some View {
        VStack(spacing: 0) {
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
