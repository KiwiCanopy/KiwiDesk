import AppKit
import KiwiDeskCore
import SwiftUI

/// The issue list shown in the standalone Config Issues panel
/// (#68 §3.7). Updated by `KiwiCore.onConfigIssuesChange`.
@MainActor
final class ConfigIssuesModel: ObservableObject {
    @Published var issues: [ConfigIssue] = []
    /// Triggers a config reload (the recheck path).
    var onReload: () -> Void = {}
    /// Deletes an unreadable profile by name; the badge clears
    /// itself through the normal config-issues refresh (#246).
    var onDeleteProfile: (String) -> Void = { _ in }
    /// Reveals a profile's JSON in Finder (#246).
    var onRevealProfile: (String) -> Void = { _ in }
}

/// A standalone small window — reachable straight from the
/// menu-bar badge, so a half-loaded config stays visible and
/// actionable even if Settings never opens (§5.7).
@MainActor
final class ConfigIssuesWindowController: NSObject {
    let model = ConfigIssuesModel()
    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.forceFront(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 460,
                height: 320
            ),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L(
            "config_issues.title",
            "Config Issues"
        )
        window.contentView = NSHostingView(
            rootView: LocaleScopedRoot {
                ConfigIssuesView(model: model)
            }
            .environmentObject(LocalizationManager.shared)
        )
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        NSApp.forceFront(window)
    }
}

/// Every load/validation error with its offending file — a
/// half-loaded config is a visible state, not a silent partial
/// start (§3.7). Surface only: the validation cores stay with
/// #39/#31.
struct ConfigIssuesView: View {
    @ObservedObject var model: ConfigIssuesModel
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.issues.isEmpty {
                emptyState
            } else {
                header
                ScrollView {
                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(model.issues) { issue in
                            row(issue)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button(
                    L(
                        "config_issues.reload",
                        "Reload config"
                    )
                ) {
                    model.onReload()
                }
                .help(
                    L(
                        "config_issues.reload.help",
                        "Re-runs the config load; fixed files "
                            + "clear their issues."
                    )
                )
            }
        }
        .padding(16)
        .frame(
            minWidth: 420,
            minHeight: 260,
            alignment: .topLeading
        )
    }

    private var header: some View {
        Label(
            L(
                "config_issues.header",
                "Parts of the configuration could not be "
                    + "loaded."
            ),
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.headline)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                L("config_issues.empty.title", "No config issues"),
                systemImage: "checkmark.circle"
            )
            .font(.headline)
            Text(
                L(
                    "config_issues.empty.body",
                    "The last configuration load completed "
                        + "cleanly."
                )
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ issue: ConfigIssue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.source)
                    .font(.system(.callout, design: .monospaced))
                    .bold()
                Text(ConfigIssueText.message(for: issue.kind))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // A remedy rides only on profile rows — an unreadable
            // profile is deletable in place, so the panel is no
            // longer a dead end (#246). Load-scoped issues
            // (init.lua/gui.json) carry no profile name and stay
            // reload-only.
            if let name = issue.profileName {
                profileActions(name)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func profileActions(_ name: String) -> some View {
        HStack(spacing: 8) {
            Button(
                L("config_issues.delete", "Delete…"),
                role: .destructive
            ) {
                confirmDelete(name)
            }
            Button(
                L("config_issues.reveal", "Reveal in Finder")
            ) {
                model.onRevealProfile(name)
            }
        }
        .controlSize(.small)
    }

    /// Modal confirm before an irreversible file delete. NSAlert
    /// (not a SwiftUI dialog) since this is a small AppKit panel
    /// with no sheet host wired.
    private func confirmDelete(_ name: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "config_issues.delete_confirm.title",
            "Delete “%1$@”?",
            name
        )
        alert.informativeText = L(
            "config_issues.delete_confirm.body",
            "This removes the profile file. It can't be undone."
        )
        let delete = alert.addButton(
            withTitle: L("config_issues.delete", "Delete…")
        )
        let cancel = alert.addButton(
            withTitle: L("config_issues.cancel", "Cancel")
        )
        // Irreversible: Cancel is the default (Return / Escape),
        // Delete needs a deliberate click (HIG).
        delete.keyEquivalent = ""
        cancel.keyEquivalent = "\r"
        if alert.runModal() == .alertFirstButtonReturn {
            model.onDeleteProfile(name)
        }
    }
}
