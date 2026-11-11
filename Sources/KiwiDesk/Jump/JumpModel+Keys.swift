import AppKit
import KiwiDeskCore

/// KiwiHub's key dispatch (#1875, #2229): a side switch, naming,
/// each side's own keys, and the Windows side's list keys.
extension JumpModel {
    /// `repeated` is a key held down: a step then stops at an end
    /// rather than wrapping past it (#2897).
    func handle(_ key: JumpKey, repeated: Bool) {
        guard !leaving else { return }
        restPointer()
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
            handleView(key, repeated: repeated)
            return
        case .desktops:
            handleDesktops(key, repeated: repeated)
            return
        }
        switch key {
        case .step(let delta):
            move(by: delta, wrap: !repeated)
        case .page(let direction):
            move(by: direction * rowCap)
        case .pick(let moveHere):
            if let index = list.selection {
                pick(index, moveHere ? .moveHere : .jump)
            }
        case .swapHere:
            if let index = list.selection { pick(index, .swapHere) }
        case .quick(let index, let moveHere):
            if list.quick(index) != nil {
                pick(index, moveHere ? .moveHere : .jump)
            }
        case .quickSwap(let index):
            if list.quick(index) != nil { pick(index, .swapHere) }
        case .escape:
            if list.query.isEmpty {
                onClose()
            } else {
                query = ""
            }
        case .dead:
            onDeadKey()
        case .side(let delta):
            stepTile(delta, wrap: !repeated)
        case .stepScope, .keep, .settings, .swallow, .openSpace,
            .leaveSpace, .pickUp, .follow:
            break
        }
    }
}
