import AppKit

/// KiwiVision (#2103): the focused window stays clear and every
/// screen dims around it. The plate follows the focus ring's
/// triggers — `updateBorders` ends in `updateVision` — so a focus
/// change, a retile and an own key window re-stack it with the
/// ring, and the target's WindowServer reorder event re-stacks it
/// once the ring has re-ordered (borders.md ▸ KiwiVision).
extension KiwiCore {
    /// Whether KiwiVision is on.
    public var kiwiVisionIsOn: Bool { vision.isOn }

    /// What KiwiVision draws now: off, plain or a lens.
    public var kiwiVisionActive: VisionActive { vision.active }

    /// The `kiwivision.*` verbs (#2103). The settings are
    /// app-wide session values, as every app-wide verb's
    /// (`setAppWide`); no window moves, so no retile.
    func visionCommand(
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        switch command {
        case "kiwivision.toggle":
            return toggleCommand(args.first?.stringValue)
        case "kiwivision.current":
            return .ok(visionCurrent())
        case "kiwivision.define_lens", "kiwivision.delete_lens":
            return lensCommand(command, args)
        case "kiwivision.set_dim":
            // Lua's whole range, as the GUI's (ruling 10, amended).
            guard let percent = args.first?.numberValue,
                percent.isFinite,
                AppWideSettings.visionDimRange.contains(percent)
            else { return .fail("expected 0-100") }
            setAppWide(persisting: false) { $0.visionDim = percent }
        case "kiwivision.set_blur":
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            setAppWide(persisting: false) { $0.visionBlur = on }
        case "kiwivision.set_appearance":
            guard
                let raw = args.first?.stringValue,
                let appearance = VisionAppearance(rawValue: raw)
            else { return .expected(VisionAppearance.self) }
            setAppWide(persisting: false) {
                $0.visionAppearance = appearance
            }
        case "kiwivision.set_fade_duration":
            let band = AppWideSettings.visionFadeRange
            guard let ms = args.first?.numberValue,
                ms >= Double(band.lowerBound), ms <= Double(band.upperBound)
            else {
                return .fail("expected \(AppWideSettings.visionFadeBand)")
            }
            setAppWide(persisting: false) {
                $0.visionFadeDuration = AppWideSettings.clampedFade(ms)
            }
        case "kiwivision.set_fade_curve":
            guard
                let raw = args.first?.stringValue,
                let curve = VisionFadeCurve(rawValue: raw)
            else { return .expected(VisionFadeCurve.self) }
            setAppWide(persisting: false) { $0.visionFadeCurve = curve }
        case "kiwivision.set_clear_wallpaper":
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            setAppWide(persisting: false) { $0.visionClearWallpaper = on }
        case "kiwivision.set_never_dimmed":
            // A Lua table arrives as one array; the CLI's words as
            // separate strings.
            var values = args
            if args.count == 1, case .array(let list) = args[0] {
                values = list
            }
            let apps = values.compactMap(\.stringValue)
            guard apps.count == values.count else {
                return .fail("expected app names")
            }
            setAppWide(persisting: false) {
                $0.visionNeverDimmed =
                    AppWideSettings.neverDimmedEntries(apps)
            }
        case "kiwivision.set_clear_app":
            guard let on = args.first?.boolValue else {
                return .fail("expected boolean")
            }
            setAppWide(persisting: false) { $0.visionClearApp = on }
        default:
            return .fail("unknown command: \(command)")
        }
        return .ok()
    }

    /// The lens KiwiVision draws, nil for plain KiwiVision or off.
    var visionLensName: String? { vision.active.lensName }

    /// What KiwiVision draws now, through the one resolver.
    var visionLook: VisionLook { appWide.look(lens: visionLensName) }

    /// The one writer of what KiwiVision draws: on, off, plain or a
    /// lens. Turning on or off pays the appearance switch; a switch
    /// between plain and a lens, or between lenses, is a change of
    /// look. Every change is heard (#2103 v3), with its `cause`
    /// where the user did not ask, which also draws its cue. `old`
    /// is the look before, for a caller whose settings already
    /// moved.
    func setVision(
        _ next: VisionActive,
        from old: VisionLook? = nil,
        cause: VisionChangeCause? = nil
    ) {
        let before = vision.active
        guard next != before else { return }
        let old = old ?? visionLook
        vision.active = next
        if before.isOn == next.isOn {
            visionLookChanged(from: old, to: visionLook)
        } else {
            if old.listedApps != visionLook.listedApps {
                vision.forgetListedWindows()
            }
            retargetVisionAppearance(
                next.isOn ? visionLook.appearance : nil
            )
            updateVision(reassertOrder: true)
        }
        if let cause { cueVisionOff(cause) }
        vision.onChange(next, cause)
    }

    /// The one door a change of what KiwiVision draws takes while
    /// it stays on — a lens switch, or a live app-wide value: the
    /// appearance follows the new ask, a new list of named apps
    /// re-reads the windows, and the plates re-draw.
    func visionLookChanged(from old: VisionLook, to new: VisionLook) {
        guard old != new else { return }
        if vision.isOn, new.appearance != old.appearance {
            retargetVisionAppearance(new.appearance)
        }
        if new.listedApps != old.listedApps {
            vision.forgetListedWindows()
        }
        updateVision()
    }

    /// Re-draws the plates from the live focus. Costs nothing
    /// while the mode is off and every plate has faded.
    func updateVision(reassertOrder: Bool = false) {
        guard
            vision.isOn || vision.hasShownPlates
                || !windowServer.requested(by: .vision).isEmpty
        else { return }
        // Read before the settle, which may end the hold.
        let heldBefore = vision.hold?.window.raw
        let focus = visionTarget()
        settleVisionHold(target: focus.target)
        var request = visionRequest(
            refreshingList: reassertOrder,
            focus: focus
        )
        if !visionMasks { vision.forgetListedWindows() }
        requestVisionWindows(target: request.target)
        request.tracked = windowServer.isActive
        request.leaving = visionLeaving(
            from: vision.target,
            to: request.target,
            heldBefore: heldBefore
        )
        vision.sync(request, reassert: reassertOrder)
    }

    /// KiwiVision's WindowServer request: the target and the float
    /// tier — a float landing re-stacks the plate — whether or not
    /// a ring or a mark asks (#2103), and the other apps' windows a
    /// mask draws, so their moves re-mask it. Hearing them costs one
    /// bounds read per move event, as a ring's does; with borders
    /// off the target and the floats pay it too, accepted while a
    /// mask is drawn.
    func requestVisionWindows(target: CGWindowID? = nil) {
        let target = target ?? vision.target
        windowServer.request(
            vision.isOn && target != nil
                ? Set(floatLayerTargets())
                    .union(target.map { [WindowID($0)] } ?? [])
                    .union(visionMaskListedIDs()) : [],
            for: .vision
        )
    }

    /// Whether the plate draws its blur now: the stored switch,
    /// stood down under Reduce transparency — what the Settings
    /// picture draws, read through the plate's own door.
    public var kiwiVisionDrawsBlur: Bool {
        kiwiVisionDrawsBlur(for: visionLook)
    }

    /// The same door over `look` — the Settings picture of a lens
    /// the draft holds (#2103 ruling 29).
    public func kiwiVisionDrawsBlur(for look: VisionLook) -> Bool {
        LiquidGlassGate.rendered(blur: look.blur)
    }

    /// Whether macOS shows Dark while KiwiVision is on: the ask
    /// over the appearance the mode found — the debt's while a
    /// switch is owed, else what macOS shows now. Never Settings'
    /// own Appearance pick. The Settings picture reads it.
    public var kiwiVisionShowsDark: Bool {
        kiwiVisionShowsDark(for: visionLook)
    }

    /// The same ask over `look`'s appearance.
    public func kiwiVisionShowsDark(for look: VisionLook) -> Bool {
        let machine = vision.appearanceSwitch
        let found =
            (vision.isOn ? machine.readDebt()?.found : nil)
            ?? machine.read()
        return look.appearance.wantsDark(over: found) ?? found.dark
    }

    /// A reorder event the plate hears. The target's re-stacks the
    /// plate after its ring's re-order (`BorderManager+WindowServer`).
    /// A float's is its raise landing directly under the focused
    /// window, above its ring and the plate (#2284): the target's
    /// overlays re-stack at once, so the float is dimmed then rather
    /// than when the whole raise lands.
    func visionWindowRestacked(_ id: WindowID) {
        guard let target = vision.target, id.raw != target else {
            vision.restack(after: id.raw)
            return
        }
        // Stood down, the restack would order the ring for nothing.
        guard vision.hasShownPlates else { return }
        // Another app's window a mask draws: its order changed the
        // mask, never the plate's place (#2103 ruling 21).
        guard state.windows[id] != nil else {
            oweVisionReshape(list: true)
            return
        }
        windowServer.restack(WindowID(target))
    }

    /// The shelf's stand-down verdict, judged once per pass in
    /// `updateBars`; a change re-draws the plates.
    func noteVisionStandDown(_ displays: Set<DisplayID>) {
        if vision.noteStandDown(displays) { updateVision() }
    }

    /// What the plates draw now. The window kept clear is the
    /// ring's focused window, or an own key window that is not it
    /// — a dialog, Sparkle's alert — which stays clear the way
    /// it stands the focused ring down (#933).
    func visionRequest(
        refreshingList: Bool = false,
        focus: VisionTarget? = nil
    ) -> VisionManager.Request {
        let focus = focus ?? visionTarget()
        let target = focus.target
        let holding = vision.hold.map(\.window.raw).flatMap {
            $0 == target ? $0 : nil
        }
        let screens = ScreenList.all.compactMap { screen in
            screen.screenNumber.map { (DisplayID($0), screen.frame) }
        }
        return VisionManager.Request(
            screens: screens,
            target: target,
            below: focus.ring,
            standDown: vision.standDown,
            tracked: windowServer.isActive,
            dim: CGFloat(visionLook.dim / 100),
            blur: kiwiVisionDrawsBlur,
            clearWallpaper: visionClearsWallpaper,
            windows: visionMasks
                ? visionMaskWindows(
                    target: target,
                    targetPid: focus.pid,
                    holding: holding,
                    refreshingList: refreshingList
                ) : [],
            holding: holding
        )
    }

    /// What `visionTarget` reads: the window kept clear, its
    /// process and the ring the plates stack under.
    typealias VisionTarget = (
        target: CGWindowID?, pid: pid_t?, ring: CGWindowID?
    )

    /// The window the plates keep clear: the ring's focused
    /// window, or an own key window that is not it, with its
    /// process and the ring the plates stack under.
    func visionTarget() -> VisionTarget {
        let anchor = activeSpace.flatMap {
            state.focusAnchor(
                of: $0,
                tiled: state.effectiveTiledMembers(of: $0)
            )
        }
        let ownKey = eventLoop.ownKeyWindow()
            // KiwiHub floats over the plate: it targets nothing.
            .flatMap { $0.floatsOverWindows ? nil : $0 }
            .flatMap { UInt32(exactly: $0.number) }
            .flatMap { $0 == anchor?.raw ? nil : $0 }
        // An own key window's app is this one.
        let pid =
            ownKey != nil
            ? getpid() : anchor.flatMap { state.windows[$0]?.pid }
        let ring =
            ownKey == nil
            ? anchor.flatMap { borders.ringPanel(of: $0) } : nil
        return (ownKey ?? anchor?.raw, pid, ring)
    }
}
