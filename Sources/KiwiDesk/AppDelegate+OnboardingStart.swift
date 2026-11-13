import AppKit
import KiwiDeskCore

/// The tour's "Start with" wiring (#3294): the offered layouts,
/// the cards each draws, and Core's doors for a Continue — a preset
/// copy on an untouched desk, an in-place replace behind one confirm
/// on a changed one, and its Revert.
extension AppDelegate {
    func wireOnboardingStart() {
        let start = onboardingModel.start
        start.offered = { [weak self] in self?.offeredTourLayouts() ?? [] }
        start.readDesk = { [weak self] offered, copy in
            self?.core.tourDesk(among: offered, copy: copy) ?? .unsaved
        }
        start.columns = { [weak self] option in
            self?.tourColumns(option) ?? []
        }
        start.start = { [weak self] layout, copy in
            guard let core = self?.core else { return .failed }
            do {
                return .started(
                    try core.withUserMotion {
                        try core.startTour(with: layout, replacing: copy)
                    }
                )
            } catch {
                core.onLog("tour start failed: \(error)")
                return .failed
            }
        }
        start.confirmReplace = { [weak self] layout, answer in
            self?.confirmSpaceReplace(layout, answer: answer)
        }
        start.replace = { [weak self] layout in
            self?.core.withUserMotion {
                self?.core.replaceSpaces(with: layout)
            } ?? false
        }
        start.captureBaseline = { [weak self] in
            self?.core.tourSpacesBaseline()
        }
        start.rereadCopy = { [weak self] copy in
            self?.core.tourCopyRead(copy)
        }
        start.restore = { [weak self] baseline in
            self?.core.withUserMotion {
                self?.core.restoreSpaces(baseline)
            } ?? false
        }
    }

    /// The starter and the presets for the connected screens.
    private func offeredTourLayouts() -> [StandardLayout] {
        let displays = PositionalDisplays.ordered(
            core.state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
        )
        return StandardProfiles.layouts(
            for: displays.count,
            sizes: displays.map(\.frame.size)
        )
    }

    /// An option's Spaces in columns, one per screen, left to right,
    /// as Core places them (`tourPlan(for:)`).
    private func tourColumns(
        _ option: OnboardingStartOption
    ) -> [OnboardingScreenColumn] {
        core.tourPlan(for: option.layout).map { column in
            OnboardingScreenColumn(
                id: String(column.display.id.raw),
                screen: column.display.name,
                cards: column.spaces.map {
                    OnboardingSpaceCard(
                        id: $0.id.raw,
                        mode: $0.mode,
                        screen: nil
                    )
                }
            )
        }
    }

    /// The one question before a changed desk's Spaces go: Replace
    /// Spaces is destructive and never the default; Cancel takes
    /// Return and Escape (`CancelDefault`). Where app rules aim at
    /// a dropped Space, a link ends the sheet as Cancel and THEN
    /// opens App Rules, closing the tour without a sheet attached.
    private func confirmSpaceReplace(
        _ layout: StandardLayout,
        answer: @escaping (Bool) -> Void
    ) {
        guard let window = onboardingWindow,
            let set = core.spaceSet(for: layout)
        else { return answer(false) }
        let leftBehind = core.appRulesLeftBehind(by: set)
        let alert = NSAlert()
        alert.alertStyle = .warning
        let preset = layout.starterTitle == nil ? layout.displayName : nil
        alert.messageText = TourReplaceText.title(preset)
        alert.informativeText = TourReplaceText.message(
            current: core.capturedSpaces.count,
            preset: preset,
            spaces: set.spaces.count,
            leftBehind: leftBehind
        )
        let replace = alert.addButton(
            withTitle: L("onboarding.start_with.replace", "Replace Spaces")
        )
        replace.hasDestructiveAction = true
        alert.addButton(
            withTitle: L("spaces.delete_confirm.cancel", "Cancel")
        )
        var opensRules = false
        let link = leftBehind.isEmpty ? nil : TourRulesLink()
        if let link {
            link.onClick = { [weak window, weak alert] in
                guard let sheet = alert?.window else { return }
                opensRules = true
                window?.endSheet(sheet, returnCode: .alertSecondButtonReturn)
            }
            alert.accessoryView = link.view
        }
        CancelDefault.beginSheet(alert, over: window) { [weak self] response in
            _ = link
            answer(response == .alertFirstButtonReturn)
            if opensRules {
                self?.openSettingsFromTour(at: .appRules)
            }
        }
    }
}
