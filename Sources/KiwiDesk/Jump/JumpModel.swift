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
    /// The Desktops side's reading and selection, read fresh on
    /// each entry to it (#1229).
    @Published var desktops: DesktopsState?
    /// Its windows' app icons, read with it.
    @Published var desktopIcons: [pid_t: NSImage] = [:]
    /// The Desktops refusal the footer shows until the next input,
    /// and what swells for a beat (#3170).
    @Published var desktopsRefusal: String?
    @Published var desktopsSwell: DesktopsSwell?
    /// The scroll the Shortcuts side's keys last asked for.
    @Published var sheetScroll = SheetScroll()
    @Published private(set) var commandHeld = false
    @Published private(set) var shiftHeld = false
    /// ⌥ previews Swap here (#2885).
    @Published private(set) var optionHeld = false
    /// Bumped each time the panel becomes key; the field takes the
    /// focus on every bump.
    @Published private(set) var fieldFocusRequests = 0

    func requestFieldFocus() { fieldFocusRequests += 1 }
    /// What the field holds while Save as New Profile… names a
    /// profile, until ↩ saves or Esc returns to picking (#2359
    /// ruling 3); nil while picking, and cleared with the side.
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
    /// still pointer lifts nothing (#2229).
    private var lastPointer: CGPoint
    /// The item the pointer lifts, grey; never the selection
    /// (#2365).
    @Published private(set) var hover: JumpHover?

    func clearHover() {
        if hover != nil { hover = nil }
    }

    /// A key, a re-rank or a side switch slides items under a still
    /// pointer: the lift clears until the next real move (#2365).
    func restPointer() {
        lastPointer = currentPointer()
        clearHover()
    }

    /// Lifts `target` on a real pointer move; an item sliding under
    /// a still one drops the lift instead.
    func noteHover(_ target: JumpHover, pointer: CGPoint) {
        if pointer != lastPointer {
            lastPointer = pointer
            if hover != target { hover = target }
        } else if hover != target {
            clearHover()
        }
    }

    /// Lifts `target` where it sits inside `container`, which took
    /// the same pointer move first.
    func noteHover(
        _ target: JumpHover,
        pointer: CGPoint,
        inside container: JumpHover?
    ) {
        if pointer == lastPointer, hover == container {
            hover = target
        } else {
            noteHover(target, pointer: pointer)
        }
    }
    /// The pointer now — the panel's one live read; a test pins
    /// it, and passes `pointer:` to `init`.
    static let livePointer: () -> CGPoint = { NSEvent.mouseLocation }
    var currentPointer = JumpModel.livePointer
    /// Each side's own chord, read from the live bindings when the
    /// panel opens; a side with none bound is absent (#2245).
    @Published var chords: [JumpScope: String] = [:]
    /// The last-app opener's chord from the live bindings, which
    /// the Windows footer names; nil where it is unbound (#3159).
    @Published var lastAppChord: String?
    /// The live settings the panel draws: its glass, its paint and
    /// the layout tiles, kept current while it is open (#2604).
    @Published var settings = TilingSettings()
    /// Each app's icon, read once when the panel opens.
    let icons: [pid_t: NSImage]
    /// The most rows the list shows before it scrolls.
    let rowCap: Int
    /// The tallest the Shortcuts side's sheet stands, from the
    /// screen it opens on (`JumpPanelController.sheetCap`).
    let sheetCap: CGFloat
    /// The panel's width on that screen
    /// (`JumpPanelController.width`).
    let panelWidth: CGFloat

    var onPick: (JumpEntry, JumpPick) -> Void = { _, _ in }
    /// A pick Core refuses at the press: what VoiceOver hears. The
    /// controller sounds it and announces it (#2885).
    var onRefuse: (String) -> Void = { _ in }
    /// A ↩ chord that picks nothing: the system beep, never the
    /// refusal sound (#2931 ▸ Ruling 4).
    var onDeadKey: () -> Void = {}
    /// Core's refusals read at the press, so a row the snapshot
    /// refused that now goes ahead reaches the verb; the controller
    /// wires Core's, a test keeps the snapshot's.
    var swapRefusal: (JumpEntry) -> JumpSwapBlock? = { $0.swapBlock }
    var moveRefusal: (JumpEntry) -> JumpMoveBlock? = { $0.moveBlock }
    /// The row whose refused press swells its reason, for a beat.
    @Published var refusedRow: Int?
    /// The row a refused press showed its reason on, until the
    /// modifier that named the pick is let go.
    @Published var revealedRow: Int?
    var onClose: () -> Void = {}
    var onAnnounce: (String) -> Void = { _ in }
    var onResultsChange: () -> Void = {}
    /// The app strip appeared or left: the panel's height slides
    /// to it, at once under Reduce Motion (#3168).
    var onStripToggle: () -> Void = {}
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
    /// Reads the whole desk now (#1229).
    var loadDesktops: () -> DesktopOverview = {
        DesktopOverview(screens: [], yours: nil)
    }
    var loadIcons: (Set<pid_t>) -> [pid_t: NSImage] = { _ in [:] }
    /// Runs a Desktops pick; the panel closes first.
    var onDesktopsAction: (DesktopsAction) -> Void = { _ in }
    /// ⌘, there: Settings ▸ Profiles, whose card binds Desktops.
    var onDesktopsSettings: () -> Void = {}
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
        panelWidth: CGFloat = JumpPanelView.width,
        modifiers: NSEvent.ModifierFlags = [],
        pointer: CGPoint? = nil
    ) {
        list = JumpList(snapshot: snapshot)
        lastPointer = pointer ?? Self.livePointer()
        self.icons = icons
        self.rowCap = rowCap
        self.sheetCap = sheetCap
        self.panelWidth = panelWidth
        noteModifiers(modifiers)
    }

    var query: String {
        get {
            switch scope {
            case .windows: return list.query
            case .shortcuts: return shortcuts?.query ?? ""
            case .view: return naming?.text ?? view?.query ?? ""
            case .desktops: return desktops?.query ?? ""
            }
        }
        set {
            guard newValue != query else { return }
            if isNaming {
                typeName(newValue)
                return
            }
            // What re-ranks under the pointer is no pointer move.
            restPointer()
            switch scope {
            case .windows: break
            case .shortcuts:
                setShortcutQuery(newValue)
                return
            case .view:
                setViewQuery(newValue)
                return
            case .desktops:
                setDesktopsQuery(newValue)
                return
            }
            let stripWas = list.stripShown
            list.setQuery(newValue)
            listChanged(stripWas: stripWas)
            onAnnounce(resultsSpoken)
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
        // ⇥ or a side switch discards a carry (#1229).
        desktops = nil
        if scope == .desktops { enterDesktops() }
        if !list.query.isEmpty { list.setQuery("") }
        // Every side switch lands Windows back on All (#3135).
        list.pickTile(0)
        view?.setQuery("")
        shortcuts?.setQuery("")
        self.scope = scope
        restPointer()
        onScopeChange()
        onAnnounce(scope.title)
    }

    /// A click selects the row, then does what ↩ does on it
    /// (#2365).
    func clickRow(_ index: Int, pick: JumpPick) {
        guard scope == .windows else { return }
        guard list.results.indices.contains(index) else { return }
        list.select(index)
        self.pick(index, pick)
    }
    /// Modifiers still held from the chord that opened or stepped
    /// the panel: none counts for a pick, a click or the lit hint
    /// until it is let go (#3168).
    private(set) var staleModifiers: NSEvent.ModifierFlags = []

    /// The opener or a step fired with `flags` held.
    func latchOpener(_ flags: NSEvent.ModifierFlags) {
        staleModifiers = flags.intersection(
            [.shift, .option, .command, .control]
        )
        noteModifiers(flags)
    }

    /// `flags` as a pick reads them: the stale ones left out.
    func pickModifiers(_ flags: NSEvent.ModifierFlags)
        -> NSEvent.ModifierFlags
    {
        flags.subtracting(staleModifiers)
    }

    func noteModifiers(_ held: NSEvent.ModifierFlags) {
        // A modifier let go is fresh from then on.
        staleModifiers.formIntersection(held)
        let flags = pickModifiers(held)
        let command = flags.contains(.command)
        let shift = flags.contains(.shift)
        let option = flags.contains(.option)
        if command != commandHeld { commandHeld = command }
        if shift != shiftHeld { shiftHeld = shift }
        if option != optionHeld { optionHeld = option }
        if !shift, !option, revealedRow != nil { revealedRow = nil }
    }

    /// The app strip's one door into the list (#3135): a tile slides
    /// rows under a still pointer, as a key does.
    func moveStrip(_ move: (inout JumpList) -> Void) {
        restPointer()
        let stripWas = list.stripShown
        move(&list)
        listChanged(stripWas: stripWas)
    }

    func move(by delta: Int, wrap: Bool = false) {
        let before = list.selection
        list.step(delta, wrap: wrap)
        if list.selection != before, let match = list.selected {
            onAnnounce(JumpRowText.spoken(match.entry))
        }
    }
}
