import Foundation
import KiwiDeskCore
import SwiftUI

/// The lens page's words (#2103 rulings 29, 46–54), one home so a
/// drawn and a spoken form cannot drift. A count goes last
/// (localization.md).
@MainActor
enum KiwiVisionLensWords {
    /// The base settings' chip, KiwiHub's word for it (#2103
    /// ruling 55).
    static var defaultName: String { ViewPickText.visionDefault }

    static var newLens: String { ViewPickText.newLens }

    static var lensName: String {
        L("kiwivision.lens.name", "Lens name")
    }

    static var add: String { L("kiwivision.lens.add", "Add") }

    static var rename: String { L("kiwivision.lens.rename", "Rename") }

    static var renameEllipsis: String {
        L("kiwivision.lens.rename_ellipsis", "Rename…")
    }

    static var deleteLens: String {
        L("kiwivision.lens.delete", "Delete Lens…")
    }

    static func deleteTitle(_ lens: String) -> String {
        L("kiwivision.lens.delete.title", "Delete the lens “%1$@”?", lens)
    }

    static var deleteMessage: String {
        L(
            "kiwivision.lens.delete.message",
            "Its shortcut goes with it. Nothing changes until you save."
        )
    }

    static var delete: String { L("kiwivision.lens.delete.confirm", "Delete") }

    /// Ruling 37's sentence: an empty lens's chip and its shortcut.
    static func noApps(_ lens: String) -> String {
        L("kiwivision.lens.no_apps", "%1$@ has no apps yet.", lens)
    }

    static func refusal(_ refusal: LensNameRefusal) -> String? {
        switch refusal {
        case .empty: return nil
        case .tooLong:
            return L(
                "kiwivision.lens.name.too_long",
                "A name can be up to %1$d characters.",
                AppWideSettings.lensNameLimit
            )
        case .taken(let holder):
            return L(
                "kiwivision.lens.name.taken",
                "A lens named “%1$@” already exists.",
                holder
            )
        }
    }

    static var appliesTo: String { L("app_rules.reach", "Applies to") }

    /// Under the header's chord row, for a chord another layer
    /// holds: the row edits the default layer's alone.
    static func chordElsewhere(_ layer: String) -> String {
        L(
            "kiwivision.lens.chord_elsewhere",
            "The “%1$@” layer has its own shortcut for this lens; "
                + "change it in %2$@.",
            layer,
            SettingsDestination.shortcuts.title
        )
    }

    static var reachCaption: String {
        L(
            "kiwivision.lens.reach.caption",
            "Built-in layouts always include every lens."
        )
    }

    /// The closed "Applies to" label over the saved profiles.
    static func reachLabel(_ reached: [String], of all: [String]) -> String {
        if reached.count == all.count { return RuleReachWords.allProfiles }
        switch reached.count {
        case 0:
            return L("kiwivision.lens.reach.none", "Built-in layouts only")
        case 1:
            return L("app_rules.reach.only", "%1$@ only", reached[0])
        case 2:
            return L(
                "app_rules.reach.pair",
                "%1$@, %2$@",
                reached[0],
                reached[1]
            )
        default:
            return L("app_rules.reach.count", "Profiles: %1$d", reached.count)
        }
    }

    // MARK: Apps

    /// The census row's help (`kiwivision.lenses`).
    static var lensesHelp: String {
        L(
            "kiwivision.lenses.help",
            "A lens is a KiwiVision of its own: the apps it keeps "
                + "clear, its own shortcut and any setting it changes. "
                + "Lens changes are kept when you save."
        )
    }

    static var appsTitle: String { L("kiwivision.lens.apps", "Apps") }

    static func appsCaption(_ lens: String) -> String {
        L(
            "kiwivision.lens.apps.caption",
            "These apps stay clear while %1$@ is on.",
            lens
        )
    }

    static var appsHelp: String {
        L(
            "kiwivision.lens.apps.help",
            "Every window of an app here stays clear while the lens is "
                + "on, on top of what the settings below keep clear. "
                + "The apps in %1$@ stay clear too.",
            SettingsCatalog.kiwiVision.neverDimmedCard.text
        )
    }

    static func appsEmpty(_ lens: String) -> String {
        L(
            "kiwivision.lens.apps.empty",
            "No apps yet. Add the apps you work in, and %1$@ keeps "
                + "them clear.",
            lens
        )
    }

    static var addApp: String { KiwiVisionNeverDimmedCard.addLabel }

    static var removeApp: String {
        L("kiwivision.lens.apps.remove", "Remove from this lens")
    }

    static var allWindows: String {
        L("kiwivision.lens.apps.all_windows", "All windows")
    }

    static var titledWindows: String {
        L("kiwivision.lens.apps.titled", "Windows titled…")
    }

    static var windowsLabel: String {
        L("kiwivision.lens.apps.windows", "Windows")
    }

    /// While a titled member has no title yet, Core keeps every
    /// window clear; the caption says so (#2103 ruling 32).
    static var titledEmptyCaption: String {
        L(
            "kiwivision.lens.apps.titled_empty",
            "Until you add a title, every window of this app stays clear."
        )
    }

    static var titledCaption: String {
        L(
            "kiwivision.lens.apps.titled_caption",
            "Only windows whose title contains one of these stay clear."
        )
    }

    // MARK: Other apps

    static var otherTitle: String {
        L("kiwivision.lens.other", "Other apps")
    }

    static func otherCaption(_ lens: String) -> String {
        L(
            "kiwivision.lens.other.caption",
            "When you switch to an app that isn't in %1$@.",
            lens
        )
    }

    static var otherHelp: String {
        L(
            "kiwivision.lens.other.help",
            "macOS still lets you switch to any app. A window you switch "
                + "to stays hazed for a moment with the reminder on it, "
                + "then clears; a click on the window clears it at once."
        )
    }

    static var keepFocus: String {
        L("kiwivision.lens.keep_focus", "Keep focus on these apps")
    }

    static var keepFocusDetail: String {
        L(
            "kiwivision.lens.keep_focus.detail",
            "KiwiDesk's focus, swap and move keys skip other apps, and a "
                + "window you switch to stays hazed for a moment."
        )
    }

    static var clearAfter: String {
        L("kiwivision.lens.clear_after", "Clear after")
    }

    /// The delay's readout: "Off" at 0 (ruling 52).
    static func delay(_ seconds: Double) -> String {
        guard seconds > 0 else { return L("kiwivision.lens.delay.off", "Off") }
        return L(
            "kiwivision.lens.delay.seconds",
            "%1$@ s",
            // The rows' own number shape, not the host's locale.
            String(
                format: seconds.rounded() == seconds ? "%.0f" : "%.1f",
                seconds
            )
        )
    }

    static var reminder: String {
        L("kiwivision.lens.reminder", "Reminder")
    }

    static var reminderDetail: String {
        L(
            "kiwivision.lens.reminder.detail",
            "Shown on the window while it waits."
        )
    }

    static var defaultReminder: String {
        L("kiwivision.reminder.default", "🥝 Keep the vision juicy 🥝")
    }

    static var needsKeepFocus: String {
        L(
            "kiwivision.lens.other.needs_keep_focus",
            "Turn on %1$@ to use these.",
            keepFocus
        )
    }

    static var needsDelay: String {
        L(
            "kiwivision.lens.other.needs_delay",
            "Set %1$@ above 0 to show a reminder.",
            clearAfter
        )
    }

    // MARK: Overrides

    static var followsCaption: String {
        L(
            "kiwivision.lens.follows.caption",
            "Unchecked rows follow %1$@.",
            defaultName
        )
    }

    static var on: String { L("kiwivision.lens.value.on", "On") }

    static var off: String { L("kiwivision.lens.value.off", "Off") }

    // MARK: Every lens

    static var everyLens: String {
        L("kiwivision.lens.every_lens", "Every lens")
    }

    static var neverDimmedCaption: String {
        L(
            "kiwivision.never_dimmed.caption",
            "Applies at once, in every profile and lens."
        )
    }

    static func panelCaption(_ lens: String, apps: [String]) -> String {
        guard !apps.isEmpty else { return noApps(lens) }
        return L(
            "kiwivision.lens.panel.caption",
            "While %1$@ is on, these stay clear: %2$@.",
            lens,
            apps.joined(separator: ", ")
        )
    }
}
