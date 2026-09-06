import KiwiDeskCore
import SwiftUI

/// Add-row view and application binding creation for ApplicationsGroup (#334).
extension ApplicationsGroup {
    /// The picker IS the add: picking commits, exactly as the app
    /// rules row does (#1235). There is no confirm step because a
    /// confirm that can only ever be pressed once after a
    /// selection carries no information.
    var addRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppPickerButton(
                placeholder: L(
                    "shortcuts.choose_app",
                    "Choose app…"
                ),
                selection: nil,
                onPick: { add($0) },
                escapeLabel: L(
                    "shortcuts.other_ellipsis",
                    "Other…"
                ),
                onEscape: {
                    if let app = AppBundlePanel.pick() {
                        add(app)
                    }
                },
                exclude: fullyBoundBundleIDs()
            )
            // Hug the content, like the per-row picker. Alone in
            // the row it would otherwise stretch to the section
            // width, read as a field rather than a control, and
            // stop lining up with the row pickers above it.
            .fixedSize()
            // The picker is the add affordance now that the
            // button is gone, so it carries the census's name —
            // and gives back the choice that name replaces
            // (#812). It shows the placeholder permanently,
            // which is right for an add VERB: its result appears
            // as a new row above.
            .accessibilityLabel(
                L("shortcuts.add_application", "Add application")
            )
            .accessibilityValue(
                L("shortcuts.choose_app", "Choose app…")
            )
            if let notice = allBoundNotice(for: nil) {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // The caption wraps beneath the picker instead of
        // widening the row into a sentence.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Why a pick at `row` created nothing, or nil.
    ///
    /// DERIVED, never a stored message: it re-asks the live
    /// question, so freeing a behavior by deleting one of that
    /// app's rows clears the sentence without anything having to
    /// notice. `refusal` only says which app to ask about and
    /// where the pick was made.
    func allBoundNotice(for row: UUID?) -> String? {
        guard let refusal, refusal.row == row else { return nil }
        return allBoundNotice(about: refusal.app)
    }

    /// The sentence for one app, asked of live state.
    ///
    /// Takes the app rather than reading `refusal` back, so the
    /// announcement never round-trips through the `@State` its
    /// own caller has just written in the same tick.
    func allBoundNotice(
        about app: KeybindingCatalog.InstalledApp
    ) -> String? {
        guard firstAvailableBehavior(for: app.bundleID) == nil
        else { return nil }
        return L(
            "shortcuts.apps.all_bound",
            "\u{201C}%1$@\u{201D} already has a key for each way "
                + "to open it. Change one of its shortcuts above "
                + "to give it another.",
            app.name
        )
    }

    /// Commits a pick, or records why it could not.
    ///
    /// The refusal has to live somewhere: the picker list omits
    /// fully-bound apps, but `AppBundlePanel.pick()` bypasses
    /// that list entirely, so the "Other…" route can still name
    /// one. The greyed Add button used to be the only thing
    /// standing there, and a dim is not a sentence (#1235).
    func add(_ app: KeybindingCatalog.InstalledApp) {
        // Seed the first behavior not already bound for this app,
        // so re-adding it lands on a distinct behavior instead of
        // a duplicate default.
        guard
            let behavior = firstAvailableBehavior(for: app.bundleID)
        else {
            refuse(app, at: nil)
            return
        }
        var binding = KeyBinding(kind: .application)
        binding.label = app.name
        binding.lua = KeybindingCatalog.appCommand(
            app.bundleID,
            behavior: behavior
        )
        bindings.append(binding)
        clearRefusal()
    }

    /// Records a refusal and speaks it once.
    ///
    /// The caption is reachable in the rotor afterwards, but the
    /// refusal lands as a modal panel dismisses and focus returns
    /// to the picker — so it is announced too. The delay is
    /// `SettingsFooter`'s measured one, taken FROM it rather than
    /// restated: a post landing in the same instant as a
    /// control's own announcement was dropped on device (#812).
    func refuse(
        _ app: KeybindingCatalog.InstalledApp,
        at row: UUID?
    ) {
        refusal = AppPickRefusal(app: app, row: row)
        refusalAnnouncement?.cancel()
        guard let sentence = allBoundNotice(about: app) else {
            return
        }
        let work = DispatchWorkItem {
            AccessibilityNotification.Announcement(sentence).post()
        }
        refusalAnnouncement = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SettingsFooter.announceDelay,
            execute: work
        )
    }

    /// Retires a refusal, cancelling a post that has not landed —
    /// so a sentence cannot be spoken after it stopped being
    /// true, which is the one place the derived caption could
    /// not protect itself.
    func clearRefusal() {
        refusalAnnouncement?.cancel()
        refusalAnnouncement = nil
        refusal = nil
    }

    /// Bundle IDs that already carry every launch behavior (#334).
    /// A per-row re-pick excludes its own row, so an app fully
    /// bound only BECAUSE of that row stays pickable.
    func fullyBoundBundleIDs(
        excluding id: UUID? = nil
    ) -> Set<String> {
        var seen: [String: Set<AppLaunchBehavior>] = [:]
        for binding in bindings
        where binding.kind == .application && binding.id != id {
            guard
                let bundleID = KeybindingCatalog.appBundleID(
                    from: binding.lua
                )
            else { continue }
            let behavior =
                KeybindingCatalog.appLaunchBehavior(
                    from: binding.lua
                ) ?? .openOrFocus
            seen[bundleID, default: []].insert(behavior)
        }
        let all = Set(AppLaunchBehavior.allCases)
        return Set(
            seen.filter { $0.value == all }.map(\.key)
        )
    }
}
