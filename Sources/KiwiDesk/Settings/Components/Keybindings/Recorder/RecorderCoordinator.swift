import Foundation
import KiwiDeskCore
import SwiftUI

/// Single-active-recorder coordinator managing keyboard capture and hotkey
/// suspension (#33, #34, #213).
@MainActor
final class RecorderCoordinator: ObservableObject {
    /// Active recording field ID.
    @Published private(set) var active: UUID?
    /// Invalidation generation counter for pending rejections.
    @Published private(set) var generation = 0
    /// Target shortcut row ID to scroll to upon rejection navigation.
    @Published var scrollTarget: String?

    /// Callback fired on transition between idle and armed states (#213).
    var onArmedChange: (Bool) -> Void = { _ in }

    /// Teardown closure for active event monitor.
    private var stopActive: (() -> Void)?

    /// Claims active recorder status, tearing down any existing monitor.
    func claim(_ id: UUID, teardown: @escaping () -> Void) {
        stopActive?()
        setActive(id)
        stopActive = teardown
    }

    func release(_ id: UUID) {
        guard active == id else { return }
        setActive(nil)
        stopActive = nil
    }

    /// Stops recording and invalidates pending rejection closures.
    func invalidate() {
        stopActive?()
        stopActive = nil
        setActive(nil)
        generation += 1
    }

    private func setActive(_ id: UUID?) {
        let wasArmed = active != nil
        active = id
        let armed = id != nil
        if armed != wasArmed { onArmedChange(armed) }
    }
}

/// Information describing a rejected shortcut recording collision (#34).
struct RecorderRejection {
    let combo: String
    let holder: String
    let holderRowID: String
    let steal: () -> Void
}

enum RecorderPreflight {
    /// Computes unique row identifier for scrolling.
    static func rowID(_ binding: KeyBinding) -> String {
        binding.kind == .navigation
            ? binding.lua : binding.id.uuidString
    }

    /// Evaluates conflicting shortcut bindings (#181 review H2).
    static func rejection(
        combo: String,
        excluding isOwn: @escaping (KeyBinding) -> Bool,
        bindings: Binding<[KeyBinding]>,
        commit: @escaping (String) -> Void
    ) -> RecorderRejection? {
        guard
            let holder = bindings.wrappedValue.first(where: {
                !$0.combo.isEmpty
                    && KeyCombo.equivalent($0.combo, combo)
                    && !isOwn($0)
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
