import Foundation

/// Which profiles a KiwiVision lens applies in (#2103 rulings 9,
/// 16, 38, 40), read from adoption state, and KiwiVision going off
/// when the live profile no longer takes the lens on.
extension KiwiCore {
    /// The live profile that leaves `lens` out, nil where the lens
    /// reaches what is live — read through the one adoption reading
    /// `liveHome`, never the file (#1245). A built-in, no live
    /// arrangement and a Lua-owned setup reach every lens (rulings
    /// 38, 40).
    func profileLeavingOut(_ lens: VisionLens) -> String? {
        // The ownership read touches disk, so it comes last.
        guard case .profile(let name)? = liveHome?.arrangement,
            profiles.active?.lensesLeftOut.contains(
                VisionLens.reachKey(lens.name)
            ) == true,
            isGuiManaged
        else { return nil }
        return name
    }

    /// The live profile changed — an apply, a write of its file, a
    /// rename, a Standard going live — or a config load moved who
    /// owns the setup (rulings 38, 40). The lens on is judged again,
    /// and every reader of a lens's reach hears it. A switch back
    /// to a profile a lens reaches turns nothing on: a switch is no
    /// press (ruling 16).
    func liveProfileChanged() {
        guard !vision.reachHeld else {
            vision.reachJudgeOwed = true
            return
        }
        followActiveLens()
        vision.onReachChange()
    }

    /// Runs a Save that writes lens marks and then the lenses, the
    /// lens on judged once both landed: judged between them, a swap
    /// of two lenses reads the lens on against the other's marks
    /// and turns it off (#2103).
    public func withLensReachHeld(_ body: () -> Void) {
        let outer = vision.reachHeld
        vision.reachHeld = true
        defer {
            vision.reachHeld = outer
            if !outer, vision.reachJudgeOwed {
                vision.reachJudgeOwed = false
                liveProfileChanged()
            }
        }
        body()
    }

    /// Ruling 16's cue: one refusal pill on the focused window
    /// naming the lens and the profile. VoiceOver hears the GUI's
    /// announcement of the same cause.
    func cueVisionOff(_ cause: VisionChangeCause) {
        guard let window = focusedWindowID else { return }
        switch cause {
        case .outOfReach(let lens, let profile):
            _ = flashRefusalPill(
                window,
                text: L(
                    "kiwivision.out_of_reach",
                    "%1$@ is off: it does not reach %2$@.",
                    lens,
                    profile
                ),
                symbol: "eyeglasses",
                // The GUI announces the same cause (#2103).
                announce: false
            )
        }
    }

    /// A lens notice (#3122): one pill on the focused window, else
    /// centred on the active Space's screen; the GUI announces it.
    func noteLensNotice(_ notice: VisionLensNotice) {
        let text = Self.lensNoticeText(notice)
        vision.onNotice(notice)
        if let window = focusedWindowID, refusalPillFrame(window) != nil {
            flashRefusalPill(
                window,
                text: text,
                symbol: "eyeglasses",
                announce: false
            )
            return
        }
        let shown = state.workspaces.activeSpace.flatMap {
            state.workspaces.display(of: $0)
        }
        let screen =
            tiler.displayFrames().first { $0.id == shown }
            ?? tiler.displayFrames().first
        guard let screen else { return }
        borders.flashScreenPill(
            display: screen.id,
            frame: screen.frame,
            text: text,
            symbol: "eyeglasses"
        )
    }

    /// The sentence a lens notice's pill draws; the GUI's
    /// announcement reads the same keys (#3122, #3276).
    static func lensNoticeText(_ notice: VisionLensNotice) -> String {
        switch notice {
        case .noMemberOpen(let lens):
            return L(
                "kiwivision.notice.no_member_open",
                "%1$@ is on: none of its apps is open.",
                lens
            )
        case .notInstalled(_, let name?):
            return L(
                "kiwivision.notice.not_installed",
                "%1$@ is not installed.",
                name
            )
        case .notInstalled(let app, nil):
            return L(
                "kiwivision.notice.not_installed_id",
                "No app with the ID %1$@ is installed.",
                app
            )
        }
    }
}
