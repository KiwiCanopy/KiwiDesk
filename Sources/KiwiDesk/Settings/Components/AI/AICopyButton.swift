import AppKit
import KiwiDeskCore
import SwiftUI

/// A button that copies `text()` to the clipboard and reads
/// "Copied" for two seconds (#1685). The swap is a state flip,
/// not an animation; VoiceOver hears it through the delayed post
/// (#812). Both labels share one frame so nothing beside it moves.
struct AICopyButton: View {
    let title: String
    let text: () -> String

    @State private var copied = false
    @State private var revert: Task<Void, Never>?
    @State private var announcement: DispatchWorkItem?

    var body: some View {
        Button(action: copy) {
            ZStack {
                label(title, "doc.on.doc")
                    .opacity(copied ? 0 : 1)
                    .accessibilityHidden(copied)
                label(copiedTitle, "checkmark")
                    .opacity(copied ? 1 : 0)
                    .accessibilityHidden(!copied)
            }
        }
        .settingsActionButton()
        .onDisappear(perform: reset)
    }

    private func label(_ text: String, _ symbol: String) -> some View {
        Label(text, systemImage: symbol)
    }

    private var copiedTitle: String { L("ai.copied", "Copied") }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text(), forType: .string)
        reset()
        copied = true
        announcement = DelayedAnnouncement.schedule(
            L("ai.copied.announcement", "Copied to the clipboard.")
        )
        revert = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private func reset() {
        revert?.cancel()
        announcement?.cancel()
        copied = false
    }
}
