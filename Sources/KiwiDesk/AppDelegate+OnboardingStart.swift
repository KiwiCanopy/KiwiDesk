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
        start.untouchedChoice = { [weak self] offered in
            self?.core.untouchedTourChoice(among: offered)
        }
        start.columns = { [weak self] option in
            self?.tourColumns(option) ?? []
        }
        start.start = { [weak self] layout, untouched in
            guard let core = self?.core else { return false }
            do {
                try core.withUserMotion {
                    try core.startTour(with: layout, replacing: untouched)
                }
                return true
            } catch {
                core.onLog("tour start failed: \(error)")
                return false
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

    /// An option's Spaces in columns, one per screen, left to right.
    private func tourColumns(
        _ option: OnboardingStartOption
    ) -> [OnboardingScreenColumn] {
        let displays = core.state.workspaces.allDisplays.sorted {
            $0.frame.minX < $1.frame.minX
        }
        let placed = placedSpaces(option)
        return displays.compactMap { display in
            let cards = placed.filter { $0.display == display.id }.map {
                OnboardingSpaceCard(id: $0.id.raw, mode: $0.mode, screen: nil)
            }
            guard !cards.isEmpty else { return nil }
            return OnboardingScreenColumn(
                id: display.fingerprint,
                screen: display.name,
                cards: cards
            )
        }
    }

    /// Each Space an option holds, with its layout and its screen.
    private func placedSpaces(
        _ option: OnboardingStartOption
    ) -> [(id: SpaceID, mode: LayoutMode, display: DisplayID?)] {
        let workspaces = core.state.workspaces
        guard let layout = option.layout,
            let set = core.spaceSet(for: layout)
        else {
            return workspaces.allSpaces.map {
                ($0.id, $0.mode, workspaces.display(of: $0.id))
            }
        }
        let main = PositionalDisplays.liveMainID
        return set.spaces.map { id in
            let pinned = set.pins[id].flatMap { pin in
                workspaces.allDisplays.first { $0.fingerprint == pin }?.id
            }
            return (id, set.spaceModes[id] ?? .bsp, pinned ?? main)
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
        alert.messageText = TourReplaceText.title(layout.displayName)
        alert.informativeText = TourReplaceText.message(
            current: core.state.workspaces.allSpaces.count,
            preset: layout.displayName,
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
