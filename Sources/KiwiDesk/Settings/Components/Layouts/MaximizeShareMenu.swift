import AppKit
import KiwiDeskCore

/// A Maximize share's menu (#3488 ▸ Ruling, option E): each
/// fraction on the left and, with a screen, the length it fills
/// there right-aligned and greyed; a stored share off the five, then
/// Custom…. An `NSMenu`, since a SwiftUI menu item has no right
/// column; it opens with the checked item over its trigger, as a
/// pop-up does.
@MainActor
enum MaximizeShareMenu {
    /// One line of the menu.
    enum Entry: Equatable {
        /// A pickable share, its glyph and its length on the screen
        /// (empty with none).
        case share(MaximizeLength, title: String, detail: String)
        case divider
        case custom
    }

    /// The menu's lines for `stored`, in order.
    static func entries(
        _ stored: MaximizeLength,
        axis: MaximizeAxis,
        region: MaximizeRegion?
    ) -> [Entry] {
        var out: [Entry] = FractionChips.shares.map { share in
            let length = MaximizeLength.fraction(share.value)
            return .share(
                length,
                title: share.glyph,
                detail: MaximizeSharePopUp.detail(
                    length,
                    axis: axis,
                    region: region
                )
            )
        }
        if let offMenu = MaximizeSharePopUp.offMenuShare(stored) {
            out += [
                .divider,
                .share(
                    offMenu,
                    title: MaximizeSharePopUp.glyph(offMenu),
                    detail: MaximizeSharePopUp.detail(
                        offMenu,
                        axis: axis,
                        region: region
                    )
                ),
            ]
        }
        return out + [.divider, .custom]
    }

    /// Opens the menu under `view`, the checked share over it.
    static func present(
        _ entries: [Entry],
        checked: MaximizeLength,
        from view: NSView,
        pick: @escaping (Entry) -> Void
    ) {
        let target = Target(entries: entries, pick: pick)
        let menu = NSMenu()
        menu.autoenablesItems = false
        let font = NSFont.menuFont(ofSize: 0)
        let stop = tabStop(entries, font: font)
        var landing: NSMenuItem?
        for (index, entry) in entries.enumerated() {
            let item: NSMenuItem
            switch entry {
            case .divider:
                menu.addItem(.separator())
                continue
            case .custom:
                item = NSMenuItem(
                    title: L("layout_defaults.maximize.custom", "Custom…"),
                    action: #selector(Target.fire(_:)),
                    keyEquivalent: ""
                )
                item.isEnabled = true
            case .share(let share, let title, let detail):
                item = NSMenuItem(
                    title: title,
                    action: #selector(Target.fire(_:)),
                    keyEquivalent: ""
                )
                item.isEnabled = true
                if !detail.isEmpty {
                    item.attributedTitle = attributed(
                        title,
                        detail,
                        stop: stop,
                        font: font
                    )
                }
                if share == checked {
                    item.state = .on
                    landing = item
                }
            }
            item.target = target
            item.tag = index
            menu.addItem(item)
        }
        // The checked item centred on the trigger, as a pop-up opens.
        let lift = view.isFlipped ? -landingLift : landingLift
        withExtendedLifetime(target) {
            _ = menu.popUp(
                positioning: landing,
                at: NSPoint(x: 0, y: view.bounds.midY + lift),
                in: view
            )
        }
    }

    /// `title`, a tab, then `detail` greyed against a right tab stop.
    static func attributed(
        _ title: String,
        _ detail: String,
        stop: CGFloat,
        font: NSFont
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.tabStops = [NSTextTab(textAlignment: .right, location: stop)]
        let text = NSMutableAttributedString(
            string: title + "\t" + detail,
            attributes: [.font: font, .paragraphStyle: style]
        )
        text.addAttribute(
            .foregroundColor,
            value: NSColor.secondaryLabelColor,
            range: NSRange(
                location: (title + "\t" as NSString).length,
                length: (detail as NSString).length
            )
        )
        return text
    }

    /// Where the lengths' right edges line up: past the widest
    /// title and a gap, the widest length's width on.
    private static func tabStop(_ entries: [Entry], font: NSFont) -> CGFloat {
        func width(_ string: String) -> CGFloat {
            (string as NSString).size(withAttributes: [.font: font]).width
        }
        var titles: CGFloat = 0
        var details: CGFloat = 0
        for case .share(_, let title, let detail) in entries {
            titles = max(titles, width(title))
            details = max(details, width(detail))
        }
        return ceil(titles + gap + details)
    }

    /// How far above the trigger's centre the positioned item's
    /// point sits for the item to centre on it: AppKit puts the
    /// item's top at the point, and a row is 24 pt (measured from
    /// the open menu's item views on macOS 27, 2026-11-19).
    private static let landingLift: CGFloat = 12

    /// The room between a fraction and its length.
    private static let gap: CGFloat = 32

    /// Holds the picks while the menu tracks; `popUp` returns after
    /// the pick, so the caller keeps it alive exactly that long.
    private final class Target: NSObject {
        let entries: [Entry]
        let pick: (Entry) -> Void

        init(entries: [Entry], pick: @escaping (Entry) -> Void) {
            self.entries = entries
            self.pick = pick
        }

        @MainActor @objc func fire(_ sender: NSMenuItem) {
            pick(entries[sender.tag])
        }
    }
}
