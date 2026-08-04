import KiwiDeskCore
import SwiftUI

/// Presentation-only pieces of `KeyRecorderField`, split out
/// to keep the field under the file-size ceiling: the
/// engagement halo around the record button and the transient
/// live-apply caption (#123).

/// The record button's stateful-input-well chrome: at rest a
/// faint recessed fill nudges it toward "field"; while
/// recording an accent fill + ring extend slightly past the
/// button so the one armed field among dozens of recorder
/// rows reads at a glance (the tint alone only recolors the
/// border). Negative padding keeps the layout footprint
/// unchanged. Deliberately NOT a rounded pill like
/// Save/Cancel: System Settings' own Keyboard Shortcuts
/// recorder reads the same way — a stateful input well, not a
/// momentary action.
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

/// The transient live-apply caption (#123). Green check = the
/// shortcut is registered and works right now; the denied
/// branch surfaces a `RegisterEventHotKey` refusal
/// (system-reserved combo) at record time instead of after a
/// Save.
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

    private var color: Color {
        switch feedback.status {
        case .applied: .green
        case .inactiveLayer: .secondary
        case .denied, .profileShadowed, .compileFailed,
            .unavailable:
            .orange
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
