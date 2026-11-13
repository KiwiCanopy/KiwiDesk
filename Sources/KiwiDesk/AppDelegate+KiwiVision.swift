import AppKit
import Combine
import KiwiDeskCore

extension AppDelegate {
    /// Every GUI reader of KiwiVision's state or its lenses: the
    /// page, its picture, the Home subtitle and KiwiHub's chips.
    /// A new reader joins here, never one trigger's closure.
    func visionReadersChanged() {
        dashboardIfCreated?.model.objectWillChange.send()
        jumpPanel?.reloadViewIfShown()
    }

    /// KiwiVision (#2103): VoiceOver hears every change, whichever
    /// door made it.
    func wireKiwiVision() {
        // A verb or a chord may change the values from outside.
        core.onAppWideChange = { [weak self] in
            self?.visionReadersChanged()
        }
        // A profile switch moves which lenses reach it.
        core.vision.onReachChange = { [weak self] in
            self?.visionReadersChanged()
        }
        // A lens holds a landing under the haze: its reminder,
        // once per landing (#2103 ruling 12).
        core.vision.onHold = { own in
            // The default is the GUI's to render (#96).
            let reminder =
                own
                ?? L(
                    "kiwivision.reminder.default",
                    "🥝 Keep the vision juicy 🥝"
                )
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: Self.spokenReminder(reminder),
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
        // A notice names a member as the lens's card does (#3276).
        core.vision.appName = KeybindingCatalog.snapshotName(forBundleID:)
        // A lens that turned on with none of its apps open (#3122).
        core.vision.onNotice = { notice in
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: Self.announcement(notice),
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
        var wasOn = core.kiwiVisionIsOn
        core.vision.onChange = { [weak self] active, cause in
            self?.visionReadersChanged()
            // A switch between lenses is no on or off to announce.
            let on = active.isOn
            guard on != wasOn else { return }
            wasOn = on
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: Self.announcement(on: on, cause: cause),
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }

    /// A reminder as VoiceOver reads it: without its emoji, which
    /// the default's kiwis would otherwise be spoken as (ruling
    /// 42a).
    static func spokenReminder(_ reminder: String) -> String {
        let kept = reminder.unicodeScalars.filter {
            !$0.properties.isEmojiPresentation
                && !($0.properties.isEmoji && $0.value > 0x7F)
                && $0.value != 0xFE0F && $0.value != 0x200D
        }
        return String(String.UnicodeScalarView(kept))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// What VoiceOver hears: on or off, or — where the user did not
    /// ask — why it went off, the sentence the pill draws (#2103
    /// ruling 16).
    static func announcement(on: Bool, cause: VisionChangeCause?) -> String {
        switch cause {
        case .outOfReach(let lens, let profile)?:
            return L(
                "kiwivision.out_of_reach",
                "%1$@ is off: it does not reach %2$@.",
                lens,
                profile
            )
        case nil:
            return on
                ? L("kiwivision.announce.on", "KiwiVision on")
                : L("kiwivision.announce.off", "KiwiVision off")
        }
    }

    /// What VoiceOver hears for a lens notice: the sentence the
    /// pill draws (#3122).
    static func announcement(_ notice: VisionLensNotice) -> String {
        switch notice {
        case .noMemberOpen(let lens):
            return L(
                "kiwivision.notice.no_member_open",
                "%1$@ is on: none of its apps is open.",
                lens
            )
        case .notInstalled(_, let name?):
            return L(
                "kiwivision.notice.not_installed",
                "%1$@ is not installed.",
                name
            )
        case .notInstalled(let app, nil):
            return L(
                "kiwivision.notice.not_installed_id",
                "No app with the bundle ID %1$@ is installed.",
                app
            )
        }
    }
}
