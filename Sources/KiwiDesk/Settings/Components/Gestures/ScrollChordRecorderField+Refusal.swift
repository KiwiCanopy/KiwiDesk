import AppKit
import KiwiDeskCore
import SwiftUI

/// The recorder's refusal caption (#1656, #1519): the other
/// gesture's chord names that gesture and offers Go to, whose
/// link names the row it reveals; any other refusal is a plain
/// sentence.
extension ScrollChordRecorderField {
    @ViewBuilder
    func refusalCaption(_ refusal: ScrollChordRefusal) -> some View {
        if case .otherGesture(let holder) = refusal, let reveal {
            let (leading, trailing) = CrossReferenceRow.split(
                Self.frame(refusal)
            )
            LinkedCaption(
                leading: leading,
                linkTitle: Self.goTo(holder),
                trailing: trailing,
                navigate: { reveal(holder) },
                ink: NSColor(SettingsTheme.ink2)
            )
        } else {
            Text(Self.caption(refusal))
                .font(.caption)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The link names its row: a bare "Go to" would end the
    /// sentence on a preposition in most locales.
    @MainActor static func goTo(_ holder: ScrollGestures.Consumer) -> String {
        L(
            "shortcuts.gestures.scroll.go_to_row",
            "Go to %1$@",
            ScrollGestureWords.label(ScrollGestureWords.field(of: holder))
        )
    }

    /// The sentence under the field for a refused chord, without
    /// its link: as announced, and where no Go to is offered.
    @MainActor static func caption(_ refusal: ScrollChordRefusal) -> String {
        frame(refusal)
            .replacingOccurrences(of: CrossReferenceRow.linkSlot, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// The refusal's sentence; the other gesture's carries the Go
    /// to link at `CrossReferenceRow.linkSlot`.
    @MainActor static func frame(_ refusal: ScrollChordRefusal) -> String {
        switch refusal {
        case .singleModifier:
            return L(
                "shortcuts.gestures.scroll.refused_single",
                "Hold two or more keys. With one key, scrolling is "
                    + "already taken: ⌃ zooms the screen in macOS, "
                    + "and ⇧, ⌥ or ⌘ do something in many apps."
            )
        case .otherGesture(.step):
            return L(
                "shortcuts.gestures.scroll.refused_step",
                "These keys already step between Spaces. %1$@",
                CrossReferenceRow.linkSlot
            )
        case .otherGesture(.pan):
            return L(
                "shortcuts.gestures.scroll.refused_pan",
                "These keys already move focus window by window. %1$@",
                CrossReferenceRow.linkSlot
            )
        }
    }
}
