import KiwiDeskCore

/// Where a move lands: a Space on a Desktop of a screen.
struct DesktopsTarget: Equatable {
    let space: SpaceID
    let desktop: DesktopOverview.Desktop
    let display: DisplayID
    let lastFocused: WindowID?
}

/// What a Desktops pick asks the controller to do (#1229). ⇧ means
/// a window moves and you stay; `follow` is ⌃'s "and follow".
enum DesktopsAction: Equatable {
    case jump(DesktopsTarget)
    case moveYours(DesktopsTarget, follow: Bool)
    case jumpDesktop(DesktopOverview.Desktop)
    case moveYoursToDesktop(DesktopOverview.Desktop)
    case jumpWindow(WindowID)
    case moveHere(WindowID)
    case swapHere(WindowID)
    case drop([WindowID], DesktopsTarget, follow: Bool)
}

/// Why a Desktops press does nothing, which the panel says.
enum DesktopsRefusal: Equatable {
    case carryBlocked(DesktopOverview.Window, DesktopOverview.CarryBlock)
    /// The Space holds no window to open.
    case emptySpace
    /// The windows no Space holds are no place to move to.
    case noSpace
    /// There is no window of yours to move.
    case nothingYours
    /// Every picked window is already in that Space.
    case alreadyThere(SpaceID)
    /// macOS numbers no such Desktop, so no verb reaches it.
    case unreachable
}

/// A press's result.
enum DesktopsOutcome: Equatable {
    /// The selection or the carry changed; nothing to run.
    case moved
    case act(DesktopsAction)
    case refuse(DesktopsRefusal)
    case close
    /// A key the side has no use for: the system beep.
    case dead
}

extension DesktopsState {
    /// The target `place` names, nil for the unfiled windows' line.
    func target(_ place: DesktopsPlace) -> DesktopsTarget? {
        guard let desktop = desktop(place), let line = line(place),
            let space = line.space
        else { return nil }
        return DesktopsTarget(
            space: space,
            desktop: desktop,
            display: overview.screens[place.screen].display,
            lastFocused: line.lastFocused
        )
    }

    /// One press, as `JumpKey` reads it on this side.
    mutating func press(_ key: JumpKey, repeated: Bool) -> DesktopsOutcome {
        switch key {
        case .step(let delta):
            if isInside {
                stepLineInside(delta)
            } else {
                moveLine(delta, wrap: !repeated)
            }
            return .moved
        case .page(let delta):
            moveLine(delta * 4, wrap: false)
            return .moved
        case .side(let delta):
            if isInside {
                stepWindow(delta, wrap: !repeated)
            } else {
                moveCard(delta, wrap: !repeated)
            }
            return .moved
        case .openSpace:
            if isInside { return .moved }
            return open() ? .moved : .refuse(.emptySpace)
        case .leaveSpace:
            leave()
            return .moved
        case .escape:
            return escape()
        case .pick(let moveHere):
            return pick(follow: false, shift: moveHere)
        case .follow:
            return pick(follow: true, shift: false)
        case .pickUp:
            guard let window else { return .dead }
            if let block = togglePick(window),
                let found = overview.window(window)
            {
                return .refuse(.carryBlocked(found, block))
            }
            return .moved
        case .swapHere:
            guard !isCarrying, let window else { return .dead }
            return .act(.swapHere(window))
        case .quick(let index, let moveHere):
            return digit(index, shift: moveHere)
        case .quickSwap, .dead, .keep, .settings, .swallow, .stepScope:
            return .dead
        }
    }

    /// Esc steps back one layer: the carry, the Space, the search,
    /// then the panel.
    private mutating func escape() -> DesktopsOutcome {
        if isCarrying {
            cancelCarry()
        } else if isInside {
            leave()
        } else if !query.isEmpty {
            setQuery("")
        } else {
            return .close
        }
        return .moved
    }

    private func pick(follow: Bool, shift: Bool) -> DesktopsOutcome {
        guard let place else { return .dead }
        if isCarrying {
            guard let target = target(place) else {
                return .refuse(.noSpace)
            }
            return drop(on: target, follow: follow)
        }
        if let window {
            if follow { return .dead }
            return .act(shift ? .moveHere(window) : .jumpWindow(window))
        }
        guard let target = target(place) else {
            return shift || follow ? .refuse(.noSpace) : .dead
        }
        if shift || follow {
            guard overview.yours != nil else { return .refuse(.nothingYours) }
            return .act(.moveYours(target, follow: follow))
        }
        return .act(.jump(target))
    }

    private func digit(_ index: Int, shift: Bool) -> DesktopsOutcome {
        guard let place = desktop(digit: index),
            let desktop = desktop(place)
        else { return .dead }
        if isCarrying {
            guard let target = target(place) else {
                return .refuse(.noSpace)
            }
            return drop(on: target, follow: false)
        }
        guard shift else { return .act(.jumpDesktop(desktop)) }
        guard overview.yours != nil else { return .refuse(.nothingYours) }
        return .act(.moveYoursToDesktop(desktop))
    }

    /// The carried windows not already in `target`'s Space.
    private func drop(
        on target: DesktopsTarget,
        follow: Bool
    ) -> DesktopsOutcome {
        let line = target.desktop.spaces.first { $0.space == target.space }
        let there = Set(line?.windows.map(\.id) ?? [])
        let moving = carried.filter { !there.contains($0) }
        guard !moving.isEmpty else {
            return .refuse(.alreadyThere(target.space))
        }
        return .act(.drop(moving, target, follow: follow))
    }
}
