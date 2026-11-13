import AppKit
import KiwiDeskCore

/// The tour replace alert's one cross-reference (#3294): a link line
/// to App Rules, shown only while rules aim at a Space the preset
/// drops. It takes neither Return nor Escape; those stay Cancel's
/// (`CancelDefault`).
@MainActor
final class TourRulesLink: NSObject {
    let view: NSButton
    var onClick: () -> Void = {}

    override init() {
        let title = L(
            "onboarding.start_with.open_rules",
            "Open %1$@ in Settings",
            SettingsDestination.appRules.title
        )
        view = LinkButton(title: title, target: nil, action: nil)
        super.init()
        view.isBordered = false
        view.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(
                    ofSize: NSFont.smallSystemFontSize
                ),
            ]
        )
        view.setAccessibilityRole(.link)
        view.target = self
        view.action = #selector(click)
        view.frame.size = view.fittingSize
    }

    @objc private func click() { onClick() }

    /// Points the hand over the link, as every link in the window.
    private final class LinkButton: NSButton {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }
}
