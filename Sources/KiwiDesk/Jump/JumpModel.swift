import AppKit
import Combine
import KiwiDeskCore

/// What the Jump to window panel shows and how its keys move it
/// (#1875), on either scope (#2229). The controller wires the
/// callbacks; the view reads the rest.
@MainActor
final class JumpModel: ObservableObject {
    @Published private(set) var list: JumpList
    @Published private(set) var scope: JumpScope = .windows
    /// The View side's lines, read fresh on each entry to it
    /// (#2309).
    @Published var view: ViewPickList?
    /// The Shortcuts side's sheet, read fresh on each entry to it
    /// (#2246).
    @Published var shortcuts: ShortcutsSheet?
    /// The scroll the Shortcuts side's keys last asked for.
    @Published var sheetScroll = SheetScroll()
    @Published private(set) var commandHeld = false
    @Published private(set) var shiftHeld = false
    /// Bumped each time the panel becomes key; the field takes the
    /// focus on every bump.
    @Published private(set) var fieldFocusRequests = 0

    func requestFieldFocus() { fieldFocusRequests += 1 }
    /// What the field holds while Save as New Profile… names a
    /// profile, until ↩ saves or Esc returns to picking (#2359
    /// ruling 3); nil while picking. Changed only through
    /// `beginNaming`, `typeName` and `endNaming`.
    @Published var naming: ProfileNaming?
    /// Bumped as naming starts: the field selects its pre-fill.
    @Published private(set) var fieldSelectAllRequests = 0

    func requestFieldSelectAll() { fieldSelectAllRequests += 1 }

    /// Whether the field names a profile rather than filtering.
    var isNaming: Bool { scope == .view && naming != nil }
    /// Set when a close starts its fade; keys stop counting.
    @Published private(set) var leaving = false

    func leave() { leaving = true }
    /// Where the pointer last moved, so a row sliding under a
    /// still pointer selects nothing (#2229).
    private var lastPointer: CGPoint
    /// The pointer now — the panel's one live read; a test pins
    /// it, and passes `pointer:` to `init`.
    static let livePointer: () -> CGPoint = { NSEvent.mouseLocation }
    var currentPointer = JumpModel.livePointer
    /// Each side's own chord, read from the live bindings when the
    /// panel opens; a side with none bound is absent (#2245).
    @Published var chords: [JumpScope: String] = [:]
    /// Each app's icon, read once when the panel opens.
    let icons: [pid_t: NSImage]
    /// The most rows the list shows before it scrolls.
    let rowCap: Int
    /// The tallest the Shortcuts side's sheet stands, from the
    /// screen it opens on (`JumpPanelController.sheetCap`).
    let sheetCap: CGFloat

    var onPick: (JumpEntry, _ moveHere: Bool) -> Void = { _, _ in }
    var onClose: () -> Void = {}
    var onAnnounce: (String) -> Void = { _ in }
    var onResultsChange: () -> Void = {}
    /// The panel's height glides to the new scope.
    var onScopeChange: () -> Void = {}
    /// Reads the View side's lines now.
    var loadView: () -> ViewPickList = {
        ViewPickList(layout: nil, kiwiVisionOn: false, items: [:])
    }
    var onApplyView: (ViewPickList.Pick) -> Void = { _ in }
    /// The name a save writes for what was typed, nil where it
    /// names no profile (`ProfileManager.newProfileName`).
    var newProfileName: (String) -> String? = { $0.isEmpty ? nil : $0 }
    /// Saves the live arrangement as the named profile; whether it
    /// landed.
    var onSaveProfile: (String) -> Bool = { _ in true }
    var onKeep: () -> Void = {}
    /// ⌘, on the View side: the Settings page of the line.
    var onViewSettings: (ViewPickList.Line, ViewPickList.Item?) -> Void =
        { _, _ in }
    /// Reads the active layer's shortcuts now; nil where
    /// `init.lua` owns them.
    var loadShortcuts: () -> ShortcutsReference? = { nil }
    var onEditShortcuts: () -> Void = {}

    init(
        snapshot: JumpSnapshot,
        icons: [pid_t: NSImage],
        rowCap: Int,
        sheetCap: CGFloat = 400,
        modifiers: NSEvent.ModifierFlags = [],
        pointer: CGPoint? = nil
    ) {
        list = JumpList(snapshot: snapshot)
        lastPointer = pointer ?? Self.livePointer()
        self.icons = icons
        self.rowCap = rowCap
        self.sheetCap = sheetCap
        noteModifiers(modifiers)
    }

    var query: String {
        get {
            switch scope {
            case .windows: return list.query
            case .shortcuts: return shortcuts?.query ?? ""
            case .view: return naming?.text ?? view?.query ?? ""
            }
        }
        set {
            guard newValue != query else { return }
            if isNaming {
                typeName(newValue)
                return
            }
            // What re-ranks under the pointer is no pointer move.
            lastPointer = currentPointer()
            switch scope {
            case .windows: break
            case .shortcuts:
                setShortcutQuery(newValue)
                return
            case .view:
                setViewQuery(newValue)
                return
            }
            list.setQuery(newValue)
            onResultsChange()
            onAnnounce(resultsSpoken)
        }
    }

    func handle(_ key: JumpKey) {
        guard !leaving else { return }
        if case .stepScope(let forward) = key {
            setScope(scope.stepped(forward: forward))
            return
        }
        if isNaming {
            handleNaming(key)
            return
        }
        switch scope {
        case .windows: break
        case .shortcuts:
            handleShortcuts(key)
            return
        case .view:
            handleView(key)
            return
        }
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
        case .stepScope, .side, .keep, .settings, .swallow:
            break
        }
    }

    /// Switches to `scope` with every query cleared (owner
    /// ruling, #2229) — a query means different things in each.
    /// View and Shortcuts read their content fresh.
    func setScope(_ scope: JumpScope) {
        guard scope != self.scope else { return }
        naming = nil
        if scope == .view { view = loadView() }
        if scope == .shortcuts {
            shortcuts = ShortcutsSheet(reference: loadShortcuts())
        }
        if !list.query.isEmpty { list.setQuery("") }
        view?.setQuery("")
        shortcuts?.setQuery("")
        self.scope = scope
        lastPointer = currentPointer()
        onScopeChange()
        onAnnounce(scope.title)
    }

    /// The selection follows the pointer, on a real move only
    /// (#2229 ▸ designer ruling): the panel opening under it, a
    /// re-rank or a scroll slides rows under a still pointer and
    /// moves nothing.
    func hoverRow(_ index: Int, pointer: CGPoint) {
        guard scope == .windows, pointerMoved(to: pointer) else { return }
        list.select(index)
    }

    func hoverItem(_ pick: ViewPickList.Pick, pointer: CGPoint) {
        guard scope == .view, pointerMoved(to: pointer) else { return }
        view?.select(pick)
    }

    private func pointerMoved(to point: CGPoint) -> Bool {
        guard point != lastPointer else { return false }
        lastPointer = point
        return true
    }

    /// ⇧ and ⌘ as held now, for the footer's one lit hint.
    var heldModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if shiftHeld { flags.insert(.shift) }
        if commandHeld { flags.insert(.command) }
        return flags
    }

    /// Whether the side shown has a selection a pick acts on.
    var hasSelection: Bool {
        switch scope {
        case .windows: return list.selected != nil
        case .shortcuts: return false
        case .view: return view?.selected?.isApplicable == true
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
