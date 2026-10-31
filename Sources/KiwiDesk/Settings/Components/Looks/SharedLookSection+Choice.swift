import KiwiDeskCore
import SwiftUI

/// The card's one choice (#2820 ▸ Ruling 1): Shared or This profile
/// only, for this page's profile alone, written at once and greyed
/// while the draft has unsaved edits. Switching an own look to
/// Shared asks first (`LookShareSheet`).
extension SharedLookSection {
    var choice: some View {
        SegmentedPicker(
            spokenLabel: choiceTitle,
            hugsLabels: true,
            selection: Binding(
                get: { follows },
                set: { pick($0) }
            ),
            options: [(sharedTitle, true), (ownTitle, false)]
        )
        .fixedSize()
    }

    private var choiceTitle: String { L("looks.reach.choice", "Look") }

    private var sharedTitle: String {
        L("looks.reach.shared", "Shared")
    }

    private var ownTitle: String {
        L("looks.reach.own_only", "This profile only")
    }

    private var follows: Bool {
        guard let edited else { return false }
        return model.lookFollows[edited] == true
    }

    private func pick(_ shared: Bool) {
        guard let edited, shared != follows else { return }
        guard shared else {
            model.applyLookSwitch(edited, .own)
            return
        }
        // No shared look yet: this profile's look seeds it, so
        // nothing is lost and nothing asks.
        guard model.core.sharedLook != nil else {
            model.applyLookSwitch(edited, .use)
            return
        }
        shareRequest = request(for: edited)
    }

    private func request(for profile: String) -> LookShareRequest {
        let draft = model.config.settings
        return LookShareRequest(
            profile: profile,
            own: draft,
            shared: model.core.sharedLook?.worn(over: draft) ?? draft,
            spaceLabels: BarsPanelPreview.spaceLabels(of: model.config),
            users: model.sharedLookUsers(besides: profile),
            savedAs: model.userLooks.first { $0.isApplied(to: draft) }?
                .name
        )
    }

    func answer(
        _ request: LookShareRequest,
        _ choice: LookShareChoice,
        saveFirst: Bool
    ) {
        if saveFirst, !saveOwnLook(of: request.profile) {
            model.profileWarning = L(
                "looks.save_failed",
                "KiwiDesk can't write your saved looks — they may come "
                    + "from a newer KiwiDesk."
            )
            return
        }
        switch choice {
        case .useShared: model.applyLookSwitch(request.profile, .use)
        case .makeShared: model.applyLookSwitch(request.profile, .make)
        }
    }

    /// Keeps the own look in My looks under the profile's name,
    /// numbered past a taken one. A refused write stages no switch:
    /// the save was the user's condition for it.
    private func saveOwnLook(of profile: String) -> Bool {
        let store = model.lookStore
        let name = KiwiCore.uniqueName(base: profile) {
            store.isBuiltinName($0) || store.hasUserLook($0)
        }
        defer { model.refreshLooks() }
        do {
            _ = try model.core.saveLook(
                named: name,
                from: model.config.settings
            )
            return true
        } catch {
            model.core.onLog("own look not saved to My looks: \(error)")
            return false
        }
    }
}
