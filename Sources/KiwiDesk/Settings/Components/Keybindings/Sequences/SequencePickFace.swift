import Foundation
import KiwiDeskCore

/// A row the action picker's one cursor stops on (`DropdownCursor`):
/// a pinned entry above the list ("Extend Sequence", a gesture's
/// families), a catalogue command, or "App…" and "Lua…" pinned below
/// it (#3162, #3183).
enum SequencePickSlot: Hashable {
    case pinned(String)
    case command(String)
    case app
    case lua
}

/// An entry pinned above the picker's list (#3183 ▸ the action
/// picker): its own id, its words and mark, whether it is the
/// current pick, and what picking it does.
struct SequencePickPin: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var picked = false
    let action: () -> Void
}

/// What the picker's trigger shows and its list checks against: an
/// end key's or a gesture row's current action (#3183).
struct SequencePickFace: Equatable {
    let id: UUID
    let kind: KeyBinding.Kind
    let lua: String
    let desc: String
    /// The trigger's words where the face names no command, such as
    /// a family; nil reads the catalogue.
    var title: String?

    init(
        id: UUID,
        kind: KeyBinding.Kind,
        lua: String,
        desc: String = "",
        title: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.lua = lua
        self.desc = desc
        self.title = title
    }

    init(_ node: KeyBinding) {
        self.init(
            id: node.id,
            kind: node.kind,
            lua: node.lua,
            desc: node.desc
        )
    }
}
