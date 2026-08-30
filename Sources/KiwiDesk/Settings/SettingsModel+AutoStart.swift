import KiwiDeskCore
import SwiftUI

/// Auto-start status and mutations for Settings (#678, #1071).
extension SettingsModel {
    /// Re-reads the live auto-start status from LaunchServices / launchctl.
    func refreshAutoStart() {
        guard !autoStartBusy else { return }
        Task {
            let status = await AutoStartManager.current()
            autoStart = status
            autoStartLoaded = true
        }
    }

    /// Sets login item enabled state (#1071, #342).
    func setLoginItem(_ enabled: Bool, reduceMotion: Bool) {
        guard autoStart.level != .atLoginWithAutoRestart else {
            return
        }
        guard enabled != autoStart.level.opensAtLogin else {
            return
        }
        guard autoStart.registerable || !enabled else { return }
        autoStartBusy = true
        Task {
            let result = await AutoStartManager.setLoginItem(
                enabled
            )
            autoStart = result
            autoStartLoaded = true
            autoStartBusy = false
            flashAutoStart(
                result.level,
                reduceMotion: reduceMotion
            )
        }
    }

    /// Displays confirmation for `level` and schedules fade (2.5s duration).
    private func flashAutoStart(
        _ level: AutoStartLevel,
        reduceMotion: Bool
    ) {
        autoStartFlashToken += 1
        let token = autoStartFlashToken
        let fade: Animation? = reduceMotion ? nil : .default
        withAnimation(fade) { autoStartApplied = level }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard autoStartFlashToken == token else { return }
            withAnimation(fade) { autoStartApplied = nil }
        }
    }

    /// True while initial status read or a write is in flight.
    var autoStartLoading: Bool {
        !autoStartLoaded || autoStartBusy
    }

    /// Gate resolver for General section auto-start rows.
    var generalGates: GeneralGates {
        GeneralGates(autoStart: autoStart)
    }
}
