import Foundation
import KiwiDeskCore
import SwiftUI

/// The one-active-recorder rule (#33): every `KeyRecorderField`
/// claims this coordinator when it starts recording, and the
/// claim *synchronously* tears the previous recorder down — no
/// window where two keyDown monitors coexist. Also carries the
/// "Go to" scroll target (#34) and a generation counter the
/// host bumps when the edited mode or target changes, so
/// pending rejections can't act on stale bindings.
@MainActor
final class RecorderCoordinator: ObservableObject {
    /// The field currently recording, if any.
    @Published private(set) var active: UUID?
    /// Bumped by `invalidate()` — fields clear their pending
    /// rejection state when it changes.
    @Published private(set) var generation = 0
    /// A row id the Shortcuts section should scroll to (the
    /// "Go to" action of a rejected recording).
    @Published var scrollTarget: String?

    /// Tears down the active field's event monitor — installed
    /// by `claim`, run synchronously before the next claim.
    private var stopActive: (() -> Void)?

    /// Starts a recording claim: the previous recorder (if
    /// any) is stopped before this one becomes active.
    func claim(_ id: UUID, teardown: @escaping () -> Void) {
        stopActive?()
        active = id
        stopActive = teardown
    }

    func release(_ id: UUID) {
        guard active == id else { return }
        active = nil
        stopActive = nil
    }

    /// The edited mode/target changed: stop any recording and
    /// invalidate pending rejection UI (its Steal closure
    /// captured pre-change bindings).
    func invalidate() {
        stopActive?()
        stopActive = nil
        active = nil
        generation += 1
    }
}

/// A rejected recording (#34): the combo is already assigned
/// to another KiwiDesk row in the same mode. The recording is
/// hard-blocked; the field offers Steal (rebind here) and
/// Go to (jump to the holder) inline. macOS system shortcuts
/// stay a soft warning (the per-row ⚠) — shadowing one can be
/// intentional.
struct RecorderRejection {
    /// The holder's display label ("Focus window above").
    let holder: String
    /// The holder's row id, for "Go to".
    let holderRowID: String
    /// Clears the holder's combo and commits it here.
    let steal: () -> Void
}

enum RecorderPreflight {
    /// The row id used by `.id(...)` on every shortcut row so
    /// "Go to" can scroll to the holder: catalog rows key by
    /// their Lua, dynamic rows by their binding id.
    static func rowID(_ binding: KeyBinding) -> String {
        binding.kind == .navigation
            ? binding.lua : binding.id.uuidString
    }

    /// Checks `combo` against every *other* row of the mode.
    /// Returns the rejection for a KiwiDesk collision, nil
    /// when the combo is free (or only shadows a system
    /// shortcut — soft, committed anyway). `commit` must look
    /// its row up at write time (id- or Lua-keyed), because
    /// Steal mutates the array first.
    static func rejection(
        combo: String,
        excluding isOwn: @escaping (KeyBinding) -> Bool,
        bindings: Binding<[KeyBinding]>,
        commit: @escaping (String) -> Void
    ) -> RecorderRejection? {
        guard
            let holder = bindings.wrappedValue.first(where: {
                !$0.combo.isEmpty && $0.combo == combo
                    && !isOwn($0)
            })
        else { return nil }
        let label =
            holder.label.isEmpty ? holder.lua : holder.label
        return RecorderRejection(
            holder: label,
            holderRowID: rowID(holder),
            steal: {
                var rows = bindings.wrappedValue
                if let index = rows.firstIndex(where: {
                    $0.id == holder.id
                }) {
                    // Catalog rows exist through their
                    // binding — removing it unbinds; dynamic
                    // rows keep their row, only the combo
                    // clears.
                    if holder.kind == .navigation {
                        rows.remove(at: index)
                    } else {
                        rows[index].combo = ""
                    }
                    bindings.wrappedValue = rows
                }
                commit(combo)
            }
        )
    }
}
