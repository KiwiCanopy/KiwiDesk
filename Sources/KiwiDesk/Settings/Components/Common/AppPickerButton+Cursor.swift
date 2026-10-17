import KiwiDeskCore
import SwiftUI

/// The app picker's one cursor (`DropdownCursor`): over the rows
/// the search left and the escape below them, seeded on the first
/// row at open and moved by the keys and real pointer motion.
extension AppPickerButton {
    typealias Lists = AppPickerSlot.Lists

    /// The popover opens: the first row, never the one under the
    /// pointer — save the guessed list, which takes no keys and so
    /// seeds none.
    func opened() {
        let first =
            guessed == nil
            ? AppPickerSlot.firstApp(of: sections)
            : nil
        cursor.opened(at: first, pointer: DropdownPointer.live())
    }

    func hover(_ slot: AppPickerSlot) {
        cursor.hover(slot, pointer: DropdownPointer.live())
    }

    /// A query edit hands the cursor to the keyboard, on the first
    /// match.
    func searched() {
        let first = AppPickerSlot.firstApp(of: sections)
        cursor.reset(to: first, pointer: DropdownPointer.live())
        scrollTarget = first
    }

    func move(_ step: Int, in lists: Lists) -> KeyPress.Result {
        guard
            let slot = cursor.keyMove(
                step,
                in: AppPickerSlot.sequence(of: lists),
                pointer: DropdownPointer.live()
            )
        else { return .handled }
        scrollTarget = slot
        // Focus stays in the search field, so VoiceOver hears the
        // cursor only if it is said.
        AccessibilityNotification.Announcement(name(of: slot, in: lists))
            .post()
        return .handled
    }

    /// Return picks the cursor's row.
    func commit(_ lists: Lists) {
        let picked = cursor.commit(
            in: AppPickerSlot.sequence(of: lists),
            pointer: DropdownPointer.live()
        )
        switch picked {
        case .onScreen(let key):
            guard let app = lists.onScreen.first(where: { $0.key == key })
            else { return }
            pick(.init(bundleID: app.key, name: app.name))
        case .installed(let id):
            guard let app = lists.all.first(where: { $0.bundleID == id })
            else { return }
            pick(app)
        case .escape:
            escape()
        case nil:
            return
        }
    }

    private func name(of slot: AppPickerSlot, in lists: Lists) -> String {
        switch slot {
        case .onScreen(let key):
            return lists.onScreen.first { $0.key == key }?.name ?? ""
        case .installed(let id):
            return lists.all.first { $0.bundleID == id }?.name ?? ""
        case .escape:
            return escapeLabel
        }
    }
}
