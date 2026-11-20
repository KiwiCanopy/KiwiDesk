import Foundation

/// `run_shortcut` (#3526): runs one of the user's Apple Shortcuts
/// by name through `AppleShortcuts`. A name the last list read does
/// not carry is refused with a pill naming it, and the list is read
/// again; before any list has been read, the press waits on one.
extension KiwiCore {
    func runShortcut(_ args: [JSONValue]) -> CommandResponse {
        guard let name = args.first?.stringValue, !name.isEmpty else {
            return .fail("expected a shortcut name")
        }
        let library = appleShortcuts
        guard let names = library.names else {
            library.refresh { [weak self] list in
                guard let self else { return }
                if list?.contains(name) ?? false {
                    self.startShortcut(name)
                } else {
                    self.refuseUnknownShortcut(name)
                }
            }
            return .ok()
        }
        guard names.contains(name) else {
            refuseUnknownShortcut(name)
            library.refresh()
            return .fail("unknown shortcut: \(name)")
        }
        startShortcut(name)
        return .ok()
    }

    private func startShortcut(_ name: String) {
        if appleShortcuts.run(name) {
            onLog("run_shortcut: running '\(name)'")
        }
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
        let symbol = "square.2.layers.3d"
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
