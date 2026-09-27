import Combine
import KiwiDeskCore

/// The boot phase the relaunched "What's new" narrates (#1667):
/// fed from the one `onBootPhaseChange` fan-out, never a count of
/// its own.
@MainActor
final class BootNarration: ObservableObject {
    @Published var phase: BootPhase

    init(phase: BootPhase = .ready) {
        self.phase = phase
    }

    /// The header's line while boot is arranging; nil once ready.
    var line: String? { BootCountText.line(for: phase) }
}
