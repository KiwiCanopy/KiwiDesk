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
}

/// A standalone small window — reachable straight from the
/// menu-bar badge, so a half-loaded config stays visible and
/// actionable even if Settings never opens (§5.7).
@MainActor
final class ConfigIssuesWindowController {
    let model = ConfigIssuesModel()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
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
        window.title = "Config Issues"
        window.contentView = NSHostingView(
            rootView: ConfigIssuesView(model: model)
        )
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Every load/validation error with its offending file — a
/// half-loaded config is a visible state, not a silent partial
/// start (§3.7). Surface only: the validation cores stay with
/// #39/#31.
struct ConfigIssuesView: View {
    @ObservedObject var model: ConfigIssuesModel

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
                Button("Reload config") {
                    model.onReload()
                }
                .help(
                    "Re-runs the config load; fixed files "
                        + "clear their issues."
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
            "Parts of the configuration could not be loaded.",
            systemImage: "doc.badge.exclamationmark"
        )
        .font(.headline)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "No config issues",
                systemImage: "checkmark.circle"
            )
            .font(.headline)
            Text(
                "The last configuration load completed "
                    + "cleanly."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ issue: ConfigIssue) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(issue.source)
                .font(.system(.callout, design: .monospaced))
                .bold()
            Text(issue.message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
    }
}
