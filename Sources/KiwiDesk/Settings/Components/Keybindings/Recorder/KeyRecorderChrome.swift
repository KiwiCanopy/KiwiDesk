import KiwiDeskCore
import SwiftUI

/// Visual styling and feedback chrome for shortcut recorder field (#123).

/// Recording well chrome displaying accent halo when armed
/// (`SettingsTheme.accent`); a DEAD chord (#1126) wears a
/// `danger` outline on the rest shape — the board's solid red
/// ring, one vocabulary.
struct RecorderButtonChrome: ViewModifier {
    let recording: Bool
    var dead = false
    /// A refused press's flash: its `danger` label is measured on
    /// the bare well, so the lift stands down while it shows.
    var flashing = false
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The idle well's grey lift under the pointer: a fill over
    /// the well, never a ring, which is the armed state's
    /// vocabulary; an armed or disabled well does not react.
    private var lifted: Bool {
        hovering && isEnabled && !recording && !flashing
    }

    func body(content: Content) -> some View {
        content
            .background {
                if !recording {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(SettingsTheme.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5).fill(
                                lifted ? SettingsTheme.chipRest : .clear
                            )
                        )
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.12),
                            value: lifted
                        )
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
                } else if dead {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            SettingsTheme.danger,
                            lineWidth: 1.5
                        )
                        .allowsHitTesting(false)
                }
            }
            .onHover { hovering = $0 }
    }
}
