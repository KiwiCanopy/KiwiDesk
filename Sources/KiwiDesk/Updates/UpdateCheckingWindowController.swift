import AppKit
import KiwiDeskCore
import SwiftUI

/// "Checking for updates…" in the update window rather than
/// Sparkle's panel (#1849): the header with a bar and one Cancel,
/// replaced by the offer or the up-to-date answer. Escape and the
/// close button cancel the check.
@MainActor
final class UpdateCheckingWindowController: NSObject, NSWindowDelegate {
    private let cancel: () -> Void
    private var window: NSWindow?

    init(cancel: @escaping () -> Void) {
        self.cancel = cancel
        super.init()
    }

    /// Brings it forward: the user asked for the check.
    func present() {
        let window = self.window ?? makeWindow()
        if !window.isVisible { window.center() }
        NSApp.forceFront(window)
    }

    /// Internal so a test takes the production window.
    func makeWindow() -> NSWindow {
        let view = UpdateCheckingView { [weak self] in self?.cancelled() }
        let probe = NSHostingView(
            rootView: LocaleScopedRoot { view }
                .environmentObject(LocalizationManager.shared)
        )
        let window = UpdateWindowChrome.window(
            root: view,
            height: probe.fittingSize.height + UpdateWindowMetrics.titleBar,
            width: UpdateCheckingView.width
        )
        window.delegate = self
        self.window = window
        return window
    }

    /// Gives way to the answer, or to Sparkle's own alert.
    func close() {
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
    }

    /// The driver's slot is the only owner, and `cancel` empties
    /// it — so this controller outlives its own call.
    private func cancelled() {
        withExtendedLifetime(self) {
            close()
            cancel()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancelled()
        return false
    }
}

/// The checking state's content: the update header with a bar
/// where the version line will be, and Cancel.
struct UpdateCheckingView: View {
    let cancel: () -> Void
    /// Alert-sized: one line, a bar and Cancel need none of the
    /// notes' width.
    static let width: CGFloat = 400

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        L(
                            "update.window.checking",
                            "Checking for updates…"
                        )
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SettingsTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    ProgressView()
                        .progressViewStyle(.linear)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 4)
            .padding(.horizontal, UpdateWindowMetrics.inset)
            .padding(.bottom, 22)
            HStack {
                Spacer(minLength: 0)
                Button(L("update.window.cancel", "Cancel"), action: cancel)
                    .settingsActionButton()
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .background(SettingsTheme.panel)
            .overlay(alignment: .top) {
                Rectangle().fill(SettingsTheme.hairline).frame(height: 1)
            }
        }
        .frame(width: Self.width)
        .updateWindowGround()
    }
}
