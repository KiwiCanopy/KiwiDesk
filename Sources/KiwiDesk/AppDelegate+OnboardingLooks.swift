import AppKit
import KiwiDeskCore

/// The tour's looks step wiring (#1720): each pick goes through
/// Core's one paint door; the Settings re-read rides the door's
/// own `onShelfPainted`, wired beside `onCapturedLive`.
extension AppDelegate {
    func wireOnboardingLooks() {
        onboardingModel.shelfLooks = { LookCatalog.bundled() }
        onboardingModel.shelfPalettes = { [weak self] in
            self?.core.allPalettes ?? []
        }
        onboardingModel.spaceLabels = { [weak self] in
            guard let self else { return [] }
            return BarsPanelPreview.spaceLabels(
                of: core.loadGuiConfig()
            )
        }
        onboardingModel.settingsDraftPending = { [weak self] in
            self?.dashboardIfCreated?.hasUnsavedDraft ?? false
        }
        onboardingModel.captureShelfBaseline = { [weak self] in
            self?.core.shelfPaintBaseline()
        }
        onboardingModel.onPaintShelf = { [weak self] look, palette in
            self?.core.paintShelf(look: look, palette: palette)
        }
        onboardingModel.baselineIsLive = { [weak self] baseline in
            self?.core.describesLiveProfile(baseline) ?? false
        }
        onboardingModel.onRestoreShelf = { [weak self] baseline in
            self?.core.restoreShelf(baseline) ?? false
        }
    }
}
