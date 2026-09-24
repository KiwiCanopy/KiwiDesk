import KiwiDeskCore
import SwiftUI

/// The pinned footer: the phase's status and its buttons (#1542
/// ruling ▸ States). Return installs, Escape means Later.
struct UpdateWindowFooter: View {
    @ObservedObject var session: UpdateSession
    /// The pressed button leaves with its phase; VoiceOver moves
    /// to the one that replaces it.
    @AccessibilityFocusState private var answerFocused: Bool
    /// With keyboard navigation on, the window rests on its
    /// answer rather than on the first link in the notes.
    @FocusState private var primaryFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            status
                .frame(maxWidth: .infinity, alignment: .leading)
            buttons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: 60)
        .background(SettingsTheme.panel)
        .onChange(of: session.phase) { answerFocused = true }
        .onAppear { primaryFocused = true }
        .overlay(alignment: .top) {
            Rectangle().fill(SettingsTheme.hairline).frame(height: 1)
        }
    }

    // MARK: - Status

    @ViewBuilder private var status: some View {
        switch session.phase {
        case .found:
            Text(
                L(
                    "update.window.keys_hint",
                    "Return installs · Esc means Later"
                )
            )
            .font(.system(size: 11))
            .foregroundStyle(SettingsTheme.ink3)
        case .downloading(let received, let expected):
            progress(
                fraction: expected.map {
                    min(Double(received) / Double(max($0, 1)), 1)
                },
                text: Self.downloadText(received, expected)
            )
        case .preparing:
            progress(fraction: nil, text: Self.preparingText)
        case .installing:
            progress(fraction: nil, text: Self.installingText)
        case .failed(let failure):
            Label {
                Text(Self.failureText(failure))
                    .foregroundStyle(SettingsTheme.ink2)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(SettingsTheme.warningInk)
            }
            .font(.system(size: 12))
        }
    }

    private func progress(fraction: Double?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let fraction {
                    ProgressView(value: fraction)
                } else {
                    ProgressView()
                }
            }
            .progressViewStyle(.linear)
            .accessibilityLabel(text)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(SettingsTheme.ink2)
                .accessibilityHidden(true)
        }
    }

    @MainActor
    static func downloadText(_ received: UInt64, _ expected: UInt64?)
        -> String
    {
        let done = bytes(received)
        guard let expected else {
            return L(
                "update.window.downloading",
                "Downloading… %1$@",
                done
            )
        }
        return L(
            "update.window.downloading_of",
            "Downloading… %1$@ of %2$@",
            done,
            bytes(max(received, expected))
        )
    }

    private static func bytes(_ count: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.zeroPadsFractionDigits = true
        return formatter.string(fromByteCount: Int64(clamping: count))
    }

    @MainActor static var preparingText: String {
        L("update.window.preparing", "Preparing…")
    }

    @MainActor static var installingText: String {
        L(
            "update.window.installing",
            "Installing… KiwiDesk quits and comes back in a moment."
        )
    }

    /// What VoiceOver hears when a phase arrives on its own —
    /// nil for one the user's own press caused.
    @MainActor
    static func announcement(_ phase: UpdateWindowPhase) -> String? {
        switch phase {
        case .preparing: return preparingText
        case .installing: return installingText
        case .failed(let failure): return failureText(failure)
        case .found, .downloading: return nil
        }
    }

    @MainActor
    static func failureText(_ failure: UpdateFailure) -> String {
        switch failure {
        case .download:
            return L(
                "update.window.failed_download",
                "The download didn't finish."
            )
        case .quit:
            return L(
                "update.window.failed_quit",
                "KiwiDesk didn't quit to install the update."
            )
        }
    }

    // MARK: - Buttons

    @ViewBuilder private var buttons: some View {
        switch session.phase {
        case .found:
            later
            primary(
                L("update.window.install", "Install and Relaunch"),
                action: session.install
            )
        case .downloading, .preparing, .installing:
            Button(L("update.window.cancel", "Cancel"), action: session.cancel)
                .settingsActionButton()
                .keyboardShortcut(.cancelAction)
                .disabled(!session.canCancel)
                .accessibilityFocused($answerFocused)
        case .failed:
            later
            primary(
                L("update.window.try_again", "Try Again"),
                action: session.tryAgain
            )
        }
    }

    private var later: some View {
        Button(L("update.window.later", "Later"), action: session.later)
            .settingsActionButton()
            .keyboardShortcut(.cancelAction)
    }

    private func primary(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .kiwiProminentButton()
            .keyboardShortcut(.defaultAction)
            .focused($primaryFocused)
            .accessibilityFocused($answerFocused)
    }
}
