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
                symbol: "eyeglasses"
            )
        }
    }
}
