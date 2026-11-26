import Combine
import KiwiDeskCore
import SwiftUI

/// What a press means in the look picker (#3038).
enum LookPickerKey: Equatable {
    /// ← (-1) or → (+1): the selection only; the desk never moves.
    case step(Int)
    /// ↩: wear the selected look, or close on the worn one.
    case wear
    /// Esc or ⌘W: close, never undo; ends a rename first.
    case escape
    /// ⌘S: quick-save the Current card (owner ruling Q5).
    case save
    /// ↩ while naming: commit the rename.
    case commitName
}

/// The look picker's state (#3038): the cards, the selection, the
/// worn card, a rename in progress, and how far the wear has come.
/// Its actions are the controller's, handed in as closures.
@MainActor
final class LookPickerModel: ObservableObject {
    enum Phase: Equatable {
        case browsing
        /// ↩ was pressed: the look is worn under the opaque overlay.
        case wearing
    }

    @Published private(set) var entries: [LookPickerEntry]
    @Published private(set) var selection: Int
    /// The card the desk wears now, if it is one of the cards.
    @Published private(set) var wornIndex: Int?
    /// The rename field's text while a quick-saved name is open.
    @Published var nameDraft: String?
    @Published private(set) var phase = Phase.browsing
    /// The live settings each card paints its look over.
    @Published var settings: TilingSettings
    let spaceLabels: [SpaceGlyph]

    var onWear: (LookPickerEntry) -> Void = { _ in }
    var onClose: () -> Void = {}
    /// Saves the worn look under its quick name; nil where refused.
    var onQuickSave: () -> ShelfLook? = { nil }
    /// Renames a saved look; the stored name, or nil where refused.
    var onRename: (_ from: String, _ to: String) -> String? = { _, _ in
        nil
    }
    var onDeadKey: () -> Void = {}
    var onAnnounce: (String) -> Void = { _ in }

    init(
        entries: [LookPickerEntry],
        worn: Int?,
        settings: TilingSettings,
        spaceLabels: [SpaceGlyph]
    ) {
        self.entries = entries
        self.wornIndex = worn
        self.selection = worn ?? 0
        self.settings = settings
        self.spaceLabels = spaceLabels
    }

    var selected: LookPickerEntry? {
        entries.indices.contains(selection) ? entries[selection] : nil
    }

    var isNaming: Bool { nameDraft != nil }

    /// `repeated` is the key held down: a step wraps on a fresh
    /// press only (#2897).
    func handle(_ key: LookPickerKey, repeated: Bool) {
        guard phase == .browsing else { return }
        switch key {
        case .step(let delta):
            guard !isNaming else { return }
            select(
                JumpList.stepped(
                    selection,
                    by: delta,
                    count: entries.count,
                    wrap: !repeated
                )
            )
        case .wear:
            guard !isNaming else { return commitName() }
            wearSelected()
        case .commitName:
            commitName()
        case .escape:
            if isNaming { nameDraft = nil } else { onClose() }
        case .save:
            quickSave()
        }
    }

    /// A stripe's click: selects that card, wears nothing.
    func select(_ index: Int) {
        guard entries.indices.contains(index), !isNaming,
            phase == .browsing
        else { return }
        let moved = index != selection
        selection = index
        if moved, let spoken = spokenSelection { onAnnounce(spoken) }
    }

    /// ↩ or a click on the card: wear it, or close on the worn one.
    func wearSelected() {
        guard phase == .browsing, let entry = selected else { return }
        guard selection != wornIndex else { return onClose() }
        phase = .wearing
        onWear(entry)
    }

    private func quickSave() {
        guard !isNaming, selected?.kind == .current,
            let saved = onQuickSave()
        else { return onDeadKey() }
        entries[selection] = LookPickerEntry(look: saved, kind: .saved)
        nameDraft = saved.name
        onAnnounce(LookPickerText.savedAs(saved.name))
    }

    private func commitName() {
        guard let draft = nameDraft, let entry = selected else { return }
        let typed = LibraryNameVerdict.normalized(draft)
        guard typed != entry.look.name else {
            nameDraft = nil
            return
        }
        guard let stored = onRename(entry.look.name, typed) else {
            return onDeadKey()
        }
        var renamed = entry.look
        renamed.name = stored
        entries[selection] = LookPickerEntry(look: renamed, kind: .saved)
        nameDraft = nil
        onAnnounce(LookPickerText.savedAs(stored))
    }

    /// What VoiceOver hears for the selection: name, line, n of m.
    var spokenSelection: String? {
        selected.map {
            LookPickerText.spoken(
                $0,
                worn: selection == wornIndex,
                position: selection + 1,
                count: entries.count
            )
        }
    }
}
