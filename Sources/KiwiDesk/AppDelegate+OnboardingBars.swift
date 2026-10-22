import AppKit
import KiwiDeskCore

/// The tour's bars step wiring (#2515): each pick goes through
/// Core's one visibility door, the Settings re-read riding that
/// door's `onLiveProfileWritten` as the looks step's paint does;
/// and the looks step's hold on the bars.
extension AppDelegate {
    func wireOnboardingBars() {
        onboardingModel.holdBarsRevealed = { [weak self] held in
            self?.core.holdBarsRevealed(held)
        }
        let bars = onboardingModel.bars
        bars.tilingSettings = { [weak self] in
            self?.core.tiler.settings ?? TilingSettings()
        }
        bars.settingsDraftPending = { [weak self] in
            self?.dashboardIfCreated?.hasUnsavedDraft ?? false
        }
        bars.captureBaseline = { [weak self] in
            self?.core.shelfPaintBaseline()
        }
        bars.baselineIsLive = { [weak self] baseline in
            self?.core.describesLiveProfile(baseline) ?? false
        }
        bars.onSetVisibility = { [weak self] visibility in
            self?.core.withUserMotion {
                self?.core.setBarVisibility(visibility)
            }
        }
        bars.onRestore = { [weak self] baseline in
            self?.core.withUserMotion {
                self?.core.restoreBarVisibility(baseline)
            } ?? false
        }
        bars.revealKeys = { [weak self] in
            guard
                let layer = self?.core.loadGuiConfig().layers.first(
                    where: { $0.isDefault }
                )
            else { return [] }
            return OnboardingKeys.revealFamilies(layer: layer)
        }
    }
}
