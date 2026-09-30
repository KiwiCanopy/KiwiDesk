import AppKit
import KiwiDeskCore

/// The bars' right-click menus' GUI half (#1518): where a Settings
/// row lands, and the Layout menu's Keep row.
extension AppDelegate {
    func wireBarMenus() {
        core.barMenuHooks.openSettings = { [weak self] landing in
            self?.dashboard.show(landing: landing)
        }
        core.barMenuHooks.keepLayout = { [weak self] in
            self?.keepLayoutInProfile()
        }
        core.barMenuHooks.confirmSpaceDelete = { question, confirmed in
            if Self.confirmsSpaceDelete(question) { confirmed() }
        }
    }

    /// A Space chip's Delete of a profile Space (#1790), in Settings'
    /// delete words: removing it from the profile is not undone by
    /// switching back.
    static func confirmsSpaceDelete(_ question: SpaceDeleteQuestion) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "bar.delete_space_confirm.title",
            "Delete Space \u{201C}%1$@\u{201D} from profile "
                + "\u{201C}%2$@\u{201D}?",
            question.space.raw,
            question.profile
        )
        if question.carriesOverrides {
            alert.informativeText = SpaceDeleteWording.overridesMessage
        }
        alert.addButton(withTitle: SpaceDeleteWording.delete)
        alert.buttons.first?.hasDestructiveAction = true
        alert.addButton(withTitle: SpaceDeleteWording.cancel)
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// The Layout menu's Keep row, from the status item or a Space
    /// chip: the layouts alone (#1179, re-ruled by #1790), the
    /// draft's baseline following through `profiles.onCapturedLive`.
    func keepLayoutInProfile() {
        do {
            try core.keepLayouts()
        } catch {
            core.onLog("profile save failed: \(error)")
            presentLayoutSaveFailure(error)
        }
    }

    /// Alerts on a layout save failure from either Layout menu.
    func presentLayoutSaveFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "menu.layout.save_failed.title",
            "Couldn't Save Layout"
        )
        alert.informativeText = L(
            "profiles.save_failed",
            "Saving failed: %1$@",
            "\(error)"
        )
        NSApp.activate()
        alert.runModal()
    }
}
