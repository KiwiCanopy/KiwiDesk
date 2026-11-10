import Foundation
import KiwiDeskCore

/// The app strip's words (#3135): Core names the apps, the strip
/// writes every label (#96).
@MainActor
enum JumpStripText {
    /// The first tile, today's flat list.
    static var allName: String { L("jump.strip.all", "All") }

    /// The strip's VoiceOver name.
    static var stripName: String { L("jump.strip.ax_label", "Apps") }

    /// Why a dimmed tile takes no pick, the list's own line.
    static var noMatch: String {
        L("jump.empty.no_match", "No open windows match")
    }

    /// What the "No windows" row's pick does: the macOS menu's own
    /// verb, which reopens an app already running.
    static var reopenHint: String {
        L("jump.strip.ax.reopen", "Opens the app")
    }

    /// A tile as VoiceOver hears it: its name, and its windows
    /// where it has more than one. The count goes last behind a
    /// label, so nothing has to agree with it.
    static func spoken(_ name: String, windows: Int) -> String {
        guard windows > 1 else { return name }
        return L("jump.strip.ax.windows", "%1$@, windows: %2$d", name, windows)
    }

    /// What a move along the strip announces: the tile, then the
    /// row the list now selects or its empty line.
    static func moved(tile: String, row: String) -> String {
        L("jump.strip.ax.moved", "%1$@: %2$@", tile, row)
    }
}
