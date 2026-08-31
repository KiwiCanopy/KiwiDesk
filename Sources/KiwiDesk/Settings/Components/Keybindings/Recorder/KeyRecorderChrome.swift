import KiwiDeskCore
import SwiftUI

/// Visual styling and feedback chrome for shortcut recorder field (#123).

/// Recording well chrome displaying accent halo when armed
/// (`SettingsTheme.accent`).
struct RecorderButtonChrome: ViewModifier {
    let recording: Bool

    func body(content: Content) -> some View {
        content
            .background {
                if !recording {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SettingsTheme.sunken)
                        .allowsHitTesting(false)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            SettingsTheme.accent.opacity(0.08)
                        )
                        .padding(-4)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if recording {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            SettingsTheme.accent.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .padding(-4)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Transient feedback caption showing live apply result or system denial
/// (#123).
struct LiveApplyCaption: View {
    let feedback: LiveApplyFeedback

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(color)
        .transition(.opacity)
    }

    private var icon: String {
        switch feedback.status {
        case .applied: "checkmark.circle.fill"
        case .inactiveLayer: "clock.badge.checkmark"
        case .denied, .profileShadowed, .compileFailed,
            .unavailable:
            "exclamationmark.circle.fill"
        }
    }

    // Theme tokens, not `.green`/`.orange`/`.secondary` (dark
    // pass): the system hues lift in dark while the kiwi accent
    // does not, `.orange` beside the amber `keyReserved` is a
    // saturated clash, and `.secondary` derives from whatever
    // ink an ancestor set rather than from a fixed grey.
    private var color: Color {
        switch feedback.status {
        case .applied: SettingsTheme.accent
        case .inactiveLayer: SettingsTheme.ink3
        case .denied, .profileShadowed, .compileFailed,
            .unavailable:
            SettingsTheme.warningInk
        }
    }

    private var text: String {
        switch feedback.status {
        case .applied:
            L(
                "key_recorder.live_applied",
                "Active now — Save to keep it"
            )
        case .inactiveLayer(let layer):
            L(
                "key_recorder.live_inactive_layer",
                "Updated for \u{201C}%1$@\u{201D} layer",
                layer
            )
        case .denied:
            L(
                "key_recorder.live_denied",
                "Recorded — the system didn't grant it"
            )
        case .profileShadowed:
            L(
                "key_recorder.live_profile_shadowed",
                "Recorded — the active profile overrides it"
            )
        case .compileFailed:
            L(
                "key_recorder.live_compile_failed",
                "Recorded — the action couldn't compile"
            )
        case .unavailable:
            L(
                "key_recorder.live_unavailable",
                "Recorded — Save to activate"
            )
        }
    }
}
