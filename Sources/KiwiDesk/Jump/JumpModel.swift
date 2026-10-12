import AppKit
import Combine
import KiwiDeskCore

/// What the Jump to window panel shows and how its keys move it
/// (#1875). The controller wires the four callbacks; the view
/// reads the rest.
@MainActor
final class JumpModel: ObservableObject {
    @Published private(set) var list: JumpList
    @Published private(set) var commandHeld = false
    @Published private(set) var shiftHeld = false
    /// Whether an input method is composing in the field; the
    /// ghost after the typed text stands down meanwhile.
    @Published private(set) var composing = false
    /// Bumped each time the panel becomes key; the field takes the
    /// focus on every bump.
    @Published private(set) var fieldFocusRequests = 0

    func requestFieldFocus() { fieldFocusRequests += 1 }
    /// Set when a close starts its fade; keys stop counting.
    @Published private(set) var leaving = false

    func leave() { leaving = true }
    /// Each app's icon, read once when the panel opens.
    let icons: [pid_t: NSImage]
    /// The most rows the list shows before it scrolls.
    let rowCap: Int

    var onPick: (JumpEntry, _ moveHere: Bool) -> Void = { _, _ in }
    var onClose: () -> Void = {}
    var onAnnounce: (String) -> Void = { _ in }
    var onResultsChange: () -> Void = {}

    init(
        snapshot: JumpSnapshot,
        icons: [pid_t: NSImage],
        rowCap: Int,
        modifiers: NSEvent.ModifierFlags = []
    ) {
        list = JumpList(snapshot: snapshot)
        self.icons = icons
        self.rowCap = rowCap
        noteModifiers(modifiers)
    }

    var query: String {
        get { list.query }
        set {
            guard newValue != list.query else { return }
            list.setQuery(newValue)
            onResultsChange()
            onAnnounce(resultsSpoken)
        }
    }

    func noteComposing(_ composing: Bool) {
        if composing != self.composing { self.composing = composing }
    }

    /// What the field shows in place of the typing; nil while an
    /// input method composes, which owns the field meanwhile.
    var field: JumpGhost.Field? {
        composing
            ? nil
            : JumpGhost.field(selected: list.selected, moveHere: shiftHeld)
    }

    func handle(_ key: JumpKey) {
        guard !leaving else { return }
        switch key {
        case .step(let delta):
            move(by: delta)
        case .page(let direction):
            move(by: direction * rowCap)
        case .pick(let moveHere):
            if let match = list.selected {
                onPick(match.entry, moveHere)
            }
        case .quick(let index, let moveHere):
            if let match = list.quick(index) {
                onPick(match.entry, moveHere)
            }
        case .escape:
            if list.query.isEmpty {
                onClose()
            } else {
                query = ""
            }
        case .swallow:
            break
        }
    }

    func noteModifiers(_ flags: NSEvent.ModifierFlags) {
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        if command != commandHeld { commandHeld = command }
        if shift != shiftHeld { shiftHeld = shift }
    }

    /// What VoiceOver hears when the results change.
    var resultsSpoken: String {
        guard list.results.isEmpty else {
            return L(
                "jump.ax.results",
                "Results: %1$d",
                list.results.count
            )
        }
        return emptyText
    }

    /// The line an empty list shows.
    var emptyText: String {
        list.snapshot.entries.isEmpty
            ? L("jump.empty.other", "No other windows")
            : L("jump.empty.no_match", "No open windows match")
    }

    private func move(by delta: Int) {
        let before = list.selection
        list.step(delta)
        if list.selection != before, let match = list.selected {
            onAnnounce(JumpRowText.spoken(match.entry))
        }
    }
}
