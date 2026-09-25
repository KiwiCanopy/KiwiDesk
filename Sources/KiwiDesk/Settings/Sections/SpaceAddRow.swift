import KiwiDeskCore
import SwiftUI

/// Settings ▸ Spaces' add row (#1531): + adds the resolved
/// `SpaceAddName`, an empty field included; Return adds only a
/// typed name, so a stray press mints nothing. A refusal is drawn
/// under the row and spoken when Return meets it.
struct SpaceAddRow: View {
    let spaces: [SpaceID]
    let onAdd: (SpaceID) -> Void

    @State private var typed = ""
    @State private var announcement: DispatchWorkItem?

    private var resolved: SpaceAddName {
        SpaceAddName.resolve(typed, among: spaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField(
                    L(
                        "spaces.add.placeholder_optional",
                        "New Space (name optional)"
                    ),
                    text: $typed
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
                Button(action: add) {
                    Image(systemName: "plus")
                }
                .disabled(resolved.space == nil)
                .settingsActionButton()
                // Icon-only like its siblings (#94) — and named for
                // VoiceOver, which `.help` is not.
                .help(L("spaces.add.help", "Add Space"))
                .accessibilityLabel(L("spaces.add.help", "Add Space"))
            }
            if let notice = resolved.notice {
                SpaceNameNoticeCaption(notice: notice)
            }
        }
        .onDisappear { announcement?.cancel() }
    }

    private func add() {
        guard let space = resolved.space else { return }
        onAdd(space)
        typed = ""
    }

    private func submit() {
        guard !typed.trimmed.isEmpty else { return }
        if let notice = resolved.notice {
            announce(notice.sentence)
            return
        }
        add()
    }

    /// `SettingsFooter`'s measured delay, as the rename field's
    /// refusal takes it (#812).
    private func announce(_ sentence: String) {
        announcement?.cancel()
        let work = DispatchWorkItem {
            AccessibilityNotification.Announcement(sentence).post()
        }
        announcement = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SettingsFooter.announceDelay,
            execute: work
        )
    }
}
