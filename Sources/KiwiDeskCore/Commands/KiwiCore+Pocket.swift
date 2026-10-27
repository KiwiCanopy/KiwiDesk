import CoreGraphics
import Foundation

/// `pocket` (#2446): the key that pockets the pocket window, takes
/// it out and puts it back (`toggle_pocket_window` marks it). The
/// slot is `StateCoordinator.pocket`; this file moves windows in
/// and out of it. A #292 focused command whose filled slot passes the
/// preflight: taking the window out acts on no focus.
extension KiwiCore {
    func pocketCommand() -> CommandResponse {
        // The press ends at an emptied slot: a filled slot passed
        // the #292 preflight, so it never acts on the focus.
        if emptyPocketIfGone() { return .ok() }
        switch state.pocket?.phase {
        case .pocketed?:
            return takePocketOut() ? .ok() : .fail("pocket is unreachable")
        case .out?:
            // Its app hidden: the unhide brings it back to the slot.
            guard let id = state.pocket?.window, state.windows[id] != nil
            else { return .fail("pocket is unreachable") }
            putInPocket(id)
            return .ok()
        case nil:
            guard let id = focusedWindowID,
                let window = state.windows[id]
            else { return .fail("no focused window") }
            guard !window.isFullscreen, !window.isTransientOverlay
            else { return .fail("this window cannot be pocketed") }
            // Marked first (#2675), its float frame read while it is
            // still in its Space and filed at the park; a window
            // already floating keeps its own.
            let becoming =
                isEffectiveFloatForPlacement(id)
                ? nil : becomePocketWindow(id)
            guard state.markPocketWindow(id)
            else { return .fail("this window cannot be pocketed") }
            putInPocket(id, filing: becoming)
            return .ok()
        }
    }

    /// Empties a slot whose untracked window's app is gone; true
    /// where it did.
    func emptyPocketIfGone() -> Bool {
        guard let slot = state.pocket, state.windows[slot.window] == nil,
            let pid = slot.pid, !eventLoop.processIdentity.runs(pid)
        else { return false }
        state.emptyPocket()
        onLog("pocket: w\(slot.window.raw) gone with its app — emptied")
        return true
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
        let cameFrom = state.pocket?.cameFrom
        let heldFocus = state.workspaces.lastFocused == id
        tiler.forgetStash(id)
        state.pocketWindow(id)
        if let becoming {
            state.rememberPocketFrame(becoming.frame, on: becoming.screen)
        }
        moveLatch.stamp(id, at: wallClock())
        onLog("pocket: w\(id.raw) pocketed")
        if heldFocus {
            let next =
                cameFrom.flatMap { focusableOnActiveSpace($0) }
                ?? activeSpace?.focused
            if let next {
                let priorFrontmost = frontmostPIDProvider?()
                focusWindow(next, refocusRetile: false, warp: true)
                scheduleMoveSettle(
                    origin: state.workspaces.activeSpace,
                    priorFrontmost: priorFrontmost
                )
            } else {
                desktopFocusYield?()
            }
        }
        retile(stateChange: id)
    }

    /// Takes the pocketed window out onto the active Space's
    /// screen, at the frame it last had there or centred, floating
    /// and focused. False where it cannot
    /// be reached: not tracked (its app hidden) or no Space to
    /// show it on.
    @discardableResult
    func takePocketOut() -> Bool {
        guard let id = state.pocketedWindow,
            let window = state.windows[id],
            let target = state.workspaces.activeSpace
        else { return false }
        let cameFrom = state.workspaces.lastFocused
        let screen = state.workspaces.display(of: target)
            .flatMap { screenFingerprint(of: $0) }
        let remembered = screen.flatMap { state.pocket?.frames[$0] }
        state.markPocketOut(cameFrom: cameFrom)
        fileMembership(id, into: target, from: nil)
        // Its frame is the slot's; the restore delivers it.
        let frame =
            remembered
            ?? floatBounds(on: target).map {
                FloatRecovery.centred(window.frame.size, in: $0)
            }
        if let frame { tiler.seedStash(id, frame: frame) }
        onLog("pocket: w\(id.raw) out on space \(target)")
        refreshStickyReach()
        retile(stateChange: id)
        focusWindow(id, refocusRetile: false, warp: true)
        raiseLandingFloats(thenFocus: id)
        return true
    }

    /// A window becoming the pocket window takes the float size
    /// there and then (#2672): the frame its float placement gives
    /// on its Space's screen, filed as the frame it comes out at
    /// there, so a take-out only restores. Nil where it may not be
    /// placed now.
    private func becomePocketWindow(
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
        let frame = tiler.commandedFrame(of: id) ?? window.frame
        guard
            let display = TilingEngine.screen(containing: frame)?
                .kiwiDisplayID,
            let screen = screenFingerprint(of: display)
        else { return }
        state.rememberPocketFrame(frame, on: screen)
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
    /// Empties the pocket for a quit: a pocketed window is filed
    /// into the active Space as the user's float, so the gather
    /// lays it out and the next launch keeps it floating; an out
    /// one stays where it is, no longer sticky.
    func releasePocketForQuit() {
        guard let slot = state.pocket,
            let id = state.releasePocketWindow()
        else { return }
        if slot.phase == .pocketed,
            let target = state.workspaces.activeSpace
        {
            // A quit's filing, no user's: the gather lays it out.
            state.workspaces.add(id, to: target)
        }
    }
}

extension KiwiCore {
    /// macOS handing the focus to the pocketed window — ⌘-Tab, the
    /// Dock, a notification — takes it out; the echo of our own
    /// pocketing does not. True where the report is spent here.
    func consumePocketedFocus(_ id: WindowID) -> Bool {
        guard state.pocketedWindow == id else { return false }
        if !moveLatch.isLatched(id, at: wallClock()) {
            onLog("focus: w\(id.raw) pocketed — taking it out")
            takePocketOut()
        }
        return true
    }
}

extension KiwiCore {
    /// The windows KiwiVision keeps clear for the pocket while it is
    /// out (#2446): the pocket window and the one it came out over.
    func visionPocketPair() -> Set<WindowID> {
        guard let slot = state.pocket, slot.phase == .out else { return [] }
        return Set([slot.window] + (slot.cameFrom.map { [$0] } ?? []))
    }
}
