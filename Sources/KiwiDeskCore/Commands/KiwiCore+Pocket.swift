import CoreGraphics
import Foundation

/// `pocket` (#2446, #2678): the key that puts pocket windows away
/// and takes them out (`toggle_pocket_window` marks them). The
/// slots are `StateCoordinator.pocket`; this file moves windows in
/// and out of it. A #292 focused command whose filled pocket passes
/// the preflight: its arms act on the slots, never the focus.
extension KiwiCore {
    func pocketCommand() -> CommandResponse {
        // A press that emptied the pocket ends there: a filled one
        // passed the #292 preflight, so it never acts on the focus.
        if emptyPocketIfGone() {
            updatePocketPlate()
            if state.generalPocket.isEmpty { return .ok() }
        }
        // Away first: the out window used last (#2678).
        if let id = state.pocketPutBackNext(focused: focusedWindowID) {
            putInPocket(id)
            return .ok()
        }
        if let id = state.pocketTakeOutNext {
            return takePocketOut(id)
                ? .ok() : .fail("pocket is unreachable")
        }
        // Out with its app hidden: the unhide brings it back. Only
        // an empty pocket marks the focus here.
        guard state.generalPocket.isEmpty else {
            return .fail("pocket is unreachable")
        }
        guard let id = focusedWindowID else {
            return .fail("no focused window")
        }
        return markAndPocket(id)
    }

    /// Empties every slot whose untracked window's app is gone;
    /// true where one was.
    func emptyPocketIfGone() -> Bool {
        let gone = state.pocket.filter {
            state.windows[$0.window] == nil
                && $0.pid.map { !eventLoop.processIdentity.runs($0) }
                    ?? false
        }
        for slot in gone {
            state.emptyPocket(slot.window)
            onLog("pocket: w\(slot.window.raw) gone with its app — emptied")
        }
        return !gone.isEmpty
    }

    /// Pockets `id`: out of its Space, parked by the next retile,
    /// and the focus handed on as a no-follow move hands it — to
    /// the window it came out over where that is still here.
    /// `becoming` is the frame a window just marked takes, filed
    /// once the slot holds it.
    func putInPocket(
        _ id: WindowID,
        filing becoming: (frame: CGRect, screen: String)? = nil
    ) {
        rememberPocketFrame(of: id)
        // Read while it still shows: the plate leaves from here.
        let released = pocketPlate.dropStart.flatMap {
            $0.window == id ? $0.released : nil
        }
        let shown = state.windows[id].map {
            released ?? tiler.commandedFrame(of: id) ?? $0.frame
        }
        let cameFrom = state.pocketSlot(of: id)?.cameFrom
        let heldFocus = state.workspaces.lastFocused == id
        tiler.forgetStash(id)
        state.pocketWindow(id)
        if let becoming {
            state.rememberPocketFrame(
                becoming.frame,
                of: id,
                on: becoming.screen
            )
        }
        onLog("pocket: w\(id.raw) pocketed")
        let next =
            heldFocus
            ? cameFrom.flatMap { focusableOnActiveSpace($0) }
                ?? activeSpace?.focused
            : nil
        // State focus moves now, so the pass pans to it; the raise
        // waits for the play to end (#2703), told what it leaves.
        let leaving = focusedWindowID
        if let next, let space = state.workspaces.space(of: next) {
            state.workspaces.focus(next, in: space)
        }
        retile(stateChange: id)
        let play = shown.flatMap {
            playBriefPocket(
                .into,
                window: id,
                frame: $0,
                on: TilingEngine.screen(containing: $0)?.kiwiDisplayID
            )
        }
        // Held through the play, whose end the hand-off waits for.
        moveLatch.stamp(
            id,
            at: wallClock(),
            holdingFor: (play?.end ?? 0) - MoveIntentLatch.window
        )
        guard heldFocus else { return handPocketFocus(after: nil, nil) }
        handPocketFocus(after: play?.handOff) { [weak self] in
            guard let self else { return }
            guard let next else {
                self.desktopFocusYield?()
                return
            }
            // And through the echo of the hand-off itself.
            self.moveLatch.stamp(id, at: self.wallClock())
            let priorFrontmost = self.frontmostPIDProvider?()
            self.focusWindow(
                next,
                refocusRetile: false,
                warp: true,
                leaving: leaving
            )
            self.scheduleMoveSettle(
                origin: self.state.workspaces.activeSpace,
                priorFrontmost: priorFrontmost
            )
        }
    }

    /// Whether `takePocketOut` takes `id` out, its own gates read
    /// ahead of it by a caller that switches first (#2791).
    func canTakePocketOut(_ id: WindowID) -> Bool {
        state.pocketPhase(of: id) == .pocketed && state.windows[id] != nil
    }

    /// Takes the pocketed window `id` out onto the active Space's
    /// screen, at the frame it last had there or centred, floating
    /// and focused. False where it cannot be reached: not pocketed,
    /// not tracked (its app hidden) or no Space to show it on.
    @discardableResult
    func takePocketOut(_ id: WindowID) -> Bool {
        guard canTakePocketOut(id), let window = state.windows[id],
            let target = state.workspaces.activeSpace
        else { return false }
        let cameFrom = state.workspaces.lastFocused
        let screen = state.workspaces.display(of: target)
            .flatMap { screenFingerprint(of: $0) }
        let remembered = screen.flatMap {
            state.pocketSlot(of: id)?.frames[$0]
        }
        state.markPocketOut(id, cameFrom: cameFrom)
        fileMembership(id, into: target, from: nil)
        // Its frame is the slot's; the restore delivers it.
        let frame =
            remembered
            ?? floatBounds(on: target).map {
                FloatRecovery.centred(window.frame.size, in: $0)
            }
        if let frame { tiler.seedStash(id, frame: frame) }
        onLog("pocket: w\(id.raw) out on space \(target)")
        // Its one write lands as the plate does (#2680).
        let play = frame.flatMap {
            playBriefPocket(
                .outOf,
                window: id,
                frame: $0,
                on: TilingEngine.screen(for: target, in: state)?
                    .kiwiDisplayID
            )
        }
        if let frame, let lands = play?.flightEnd {
            tiler.applier.holdWrites([id], until: .now() + lands)
            holdRingThroughLanding(id, target: frame, lands: lands)
        }
        refreshStickyReach()
        retile(stateChange: id)
        // Raised as it lands, under the plate's fade, sharing the
        // held write's deadline unordered (#2845).
        handPocketFocus(after: play?.handOff, leaving: cameFrom) {
            [weak self] in
            guard let self, self.state.pocketPhase(of: id) == .out
            else { return }
            self.focusWindow(id, refocusRetile: false, warp: true)
            self.raiseLandingFloats(thenFocus: id)
        }
        return true
    }

    /// A window becoming the pocket window takes the float size
    /// there and then (#2672): the frame its float placement gives
    /// on its Space's screen, filed as the frame it comes out at
    /// there, so a take-out only restores. Nil where it may not be
    /// placed now.
    func becomePocketWindow(
        _ id: WindowID
    ) -> (frame: CGRect, screen: String)? {
        guard
            let screen = floatPlacementSpace(of: id)
                .flatMap({ state.workspaces.display(of: $0) })
                .flatMap({ screenFingerprint(of: $0) }),
            let frame = floatPlacementFrame(for: id)
        else { return nil }
        // A size outside the layout's asks (#677).
        tiler.forgetSizeBound(id)
        return (frame, screen)
    }

    /// Files the window's frame under the screen it sits on, while
    /// it is out.
    private func rememberPocketFrame(of id: WindowID) {
        guard state.pocketPhase(of: id) == .out,
            let window = state.windows[id]
        else { return }
        let dropped = pocketPlate.dropStart.flatMap {
            $0.window == id ? $0.frame : nil
        }
        let frame = dropped ?? tiler.commandedFrame(of: id) ?? window.frame
        guard
            let display = TilingEngine.screen(containing: frame)?
                .kiwiDisplayID,
            let screen = screenFingerprint(of: display)
        else { return }
        state.rememberPocketFrame(frame, of: id, on: screen)
    }

    /// `id` where it still draws on the active Space.
    private func focusableOnActiveSpace(_ id: WindowID) -> WindowID? {
        guard let window = state.windows[id],
            state.renderSpace(of: window) == state.workspaces.activeSpace
        else { return nil }
        return id
    }
}

extension KiwiCore {
    /// A sticky verb on a pocket window (#2446): it already comes
    /// out wherever you are, so the scope is not the user's to set.
    func refusePocketSticky(_ id: WindowID) -> CommandResponse {
        soundIfDrawn(
            flashRefusalPill(
                id,
                text: PocketRefusal.stickySentence,
                symbol: AutoFloatReason.pocket.pillSymbol,
                announce: true
            )
        )
        return .fail("pocket windows are always sticky")
    }
}

extension KiwiCore {
    /// Empties the pocket for a quit: each pocketed window is filed
    /// into the active Space as the user's float, so the gather
    /// lays it out and the next launch keeps it floating; an out
    /// one stays where it is, no longer sticky.
    func releasePocketForQuit() {
        for slot in state.pocket {
            guard let id = state.releasePocketWindow(slot.window)
            else { continue }
            if slot.phase == .pocketed,
                let target = state.workspaces.activeSpace
            {
                // A quit's filing, no user's: the gather lays it out.
                state.workspaces.add(id, to: target)
            }
        }
    }
}

extension KiwiCore {
    /// macOS handing the focus to a pocketed window — ⌘-Tab, the
    /// Dock, a notification — takes it out; the echo of our own
    /// pocketing does not. True where the report is spent here.
    func consumePocketedFocus(_ id: WindowID) -> Bool {
        guard state.isPocketed(id) else { return false }
        if !moveLatch.isLatched(id, at: wallClock()) {
            onLog("focus: w\(id.raw) pocketed — taking it out")
            takePocketOut(id)
        }
        return true
    }
}

extension KiwiCore {
    /// The windows KiwiVision keeps clear for the pocket (#2446):
    /// each out pocket window and the one it came out over.
    func visionPocketPair() -> Set<WindowID> {
        Set(
            state.pocket.filter { $0.phase == .out }.flatMap {
                [$0.window] + ($0.cameFrom.map { [$0] } ?? [])
            }
        )
    }
}
