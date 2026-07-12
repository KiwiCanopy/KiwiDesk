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
    /// The combo that was rejected — kept so the field can
    /// re-validate against live bindings (the holder may have
    /// been cleared since).
    let combo: String
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
        silentSteal: (KeyBinding) -> Bool = { _ in false },
        bindings: Binding<[KeyBinding]>,
        commit: @escaping (String) -> Void
    ) -> RecorderRejection? {
        // A PURE query: it runs from chord previews (every
        // in-flight chord change) and from render passes, so
        // it must never mutate the bindings (#181 review H2 —
        // a preview keystroke deleted an inert row, and a
        // body evaluation mutated state mid-update). A combo
        // held only by inert gated rows reads as free here;
        // the commit writers perform the actual silent steal
        // via `stealInert` once the chord locks in.
        guard
            let holder = bindings.wrappedValue.first(where: {
                !$0.combo.isEmpty && $0.combo == combo
                    && !isOwn($0) && !silentSteal($0)
            })
        else { return nil }
        let label =
            holder.label.isEmpty ? holder.lua : holder.label
        return RecorderRejection(
            combo: combo,
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

    /// Silently unbinds every inert gated holder of `combo`
    /// (#181): catalog rows unbind by removal (like the
    /// prompted Steal), dynamic rows keep the row and only
    /// clear the combo. Called from the commit writers ONLY —
    /// the preflight query above stays pure; the Steal prompt
    /// would point at a row the GUI no longer renders, hence
    /// no prompt.
    /// `excluding` guards the committing row itself: the
    /// element-binding writers set the combo BEFORE stealing
    /// (structural-mutation safety), and a rendered `.custom`
    /// row whose Lua is byte-exactly a gated body would
    /// otherwise steal its own fresh combo (review).
    static func stealInert(
        combo: String,
        excluding excluded: UUID? = nil,
        stealable: (KeyBinding) -> Bool,
        bindings: inout [KeyBinding]
    ) {
        for index in bindings.indices.reversed()
        where bindings[index].combo == combo
            && bindings[index].id != excluded
            && stealable(bindings[index])
        {
            if bindings[index].kind == .navigation {
                bindings.remove(at: index)
            } else {
                bindings[index].combo = ""
            }
        }
    }
}
