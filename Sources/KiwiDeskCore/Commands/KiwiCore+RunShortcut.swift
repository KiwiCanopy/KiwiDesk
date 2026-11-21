import Foundation

/// `run_shortcut` (#3526): runs one of the user's Apple Shortcuts
/// by name through `AppleShortcuts`. A name the last list lacks is
/// checked against a fresh read before it is refused, so a shortcut
/// made or renamed since is never refused; a list that cannot be
/// read refuses nothing, and `shortcuts run` answers for itself.
extension KiwiCore {
    func runShortcut(_ args: [JSONValue]) -> CommandResponse {
        guard let name = args.first?.stringValue, !name.isEmpty else {
            return .fail("expected a shortcut name")
        }
        let library = appleShortcuts
        if library.names?.contains(name) != true {
            switch library.readNow() {
            case let list? where !list.contains(name):
                refuseUnknownShortcut(name)
                return .fail("unknown shortcut: \(name)")
            case nil:
                onLog("run_shortcut: list unreadable, running '\(name)'")
            default:
                break
            }
        }
        if library.run(name) {
            onLog("run_shortcut: running '\(name)'")
        }
        return .ok()
    }

    /// The pill on the focused window, else centred on the active
    /// Space's screen, as a lens notice draws (#3122).
    private func refuseUnknownShortcut(_ name: String) {
        onLog("run_shortcut: no shortcut named '\(name)'")
        let text = L(
            "run_shortcut.refusal.unknown",
            "No shortcut is named \u{201C}%1$@\u{201D} in the "
                + "Shortcuts app",
            name
        )
        let symbol = AppleShortcuts.symbol
        if let window = focusedWindowID, refusalPillFrame(window) != nil {
            soundIfDrawn(
                flashRefusalPill(
                    window,
                    text: text,
                    symbol: symbol,
                    announce: true
                )
            )
            return
        }
        borders.announceRefusal(text)
        let shown = state.workspaces.activeSpace.flatMap {
            state.workspaces.display(of: $0)
        }
        let screen =
            tiler.displayFrames().first { $0.id == shown }
            ?? tiler.displayFrames().first
        guard let screen else { return }
        soundIfDrawn(
            borders.flashScreenPill(
                display: screen.id,
                frame: screen.frame,
                text: text,
                symbol: symbol
            )
        )
    }
}
