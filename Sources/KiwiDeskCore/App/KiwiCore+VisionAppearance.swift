import Foundation

/// KiwiVision's appearance while on (#2103 ruling 7): turning the
/// mode on switches the system appearance only where it differs;
/// turning it off switches back only a switch KiwiVision made and
/// nobody changed since. The debt is stored before the switch, so
/// a quit or a crash pays it at the next start.
extension KiwiCore {
    /// `kiwivision.set_appearance`: a live mode takes the new ask
    /// at once, paying any switch the old one made.
    func setVisionAppearance(_ appearance: VisionAppearance) {
        vision.appearanceWhileOn = appearance
        guard vision.isOn else { return }
        payVisionAppearanceDebt()
        applyVisionAppearance()
    }

    /// The mode turned on: switches when the ask differs from
    /// what the system shows.
    func applyVisionAppearance() {
        let machine = vision.appearanceSwitch
        let found = machine.read()
        guard
            let want = vision.appearanceWhileOn.wantsDark(over: found),
            found.dark != want
        else { return }
        let debt = VisionAppearanceDebt(found: found, setDark: want)
        guard machine.writeDebt(debt) else {
            onLog("kiwivision: appearance debt not stored; no switch")
            return
        }
        machine.setDark(want)
    }

    /// The mode turned off, the core stopped, or a start found an
    /// unpaid switch: puts back what KiwiVision changed, unless
    /// the user changed it since.
    func payVisionAppearanceDebt() {
        let machine = vision.appearanceSwitch
        guard let debt = machine.readDebt() else { return }
        _ = machine.writeDebt(nil)
        let now = machine.read()
        guard now.dark == debt.setDark else { return }
        if now.dark != debt.found.dark {
            machine.setDark(debt.found.dark)
        }
        if debt.found.auto && !now.auto {
            machine.rearmAuto()
        }
    }
}
