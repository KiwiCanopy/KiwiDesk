import AppKit
import SwiftUI

/// Caption sentence with an embedded clickable link formatted via AppKit
/// (device 2026-08-03, code review 2026-08-12;
/// tested in `LinkedCaptionHitTests`).
struct LinkedCaption: NSViewRepresentable {
    let leading: String
    let linkTitle: String
    let trailing: String
    let navigate: () -> Void
    var pointSize: CGFloat = NSFont.preferredFont(
        forTextStyle: .caption1
    ).pointSize
    var ink: NSColor = .secondaryLabelColor
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> CaptionTextView {
        let view = CaptionTextView.configured()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(
        _ view: CaptionTextView,
        context: Context
    ) {
        view.onLink = navigate
        view.linkLabel = linkTitle
        view.isLive = isEnabled
        view.restingInk = ink
        view.setSentence(sentence, linkRange: linkRange)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: CaptionTextView,
        context: Context
    ) -> CGSize? {
        guard
            let width = proposal.width,
            width > 0,
            width < .greatestFiniteMagnitude,
            let container = nsView.textContainer,
            let manager = nsView.layoutManager
        else { return nil }
        container.containerSize = CGSize(
            width: width,
            height: .greatestFiniteMagnitude
        )
        manager.ensureLayout(for: container)
        return CGSize(
            width: width,
            height: ceil(manager.usedRect(for: container).height)
        )
    }

    /// Splits frame text around the `%1$@` link format specifier.
    static func split(frame: String) -> (String, String) {
        guard let slot = frame.range(of: "%1$@") else {
            assertionFailure("frame has no link slot")
            return (frame + " ", "")
        }
        return (
            String(frame[..<slot.lowerBound]),
            String(frame[slot.upperBound...])
        )
    }

    private var linkRange: NSRange {
        NSRange(
            location: (leading as NSString).length,
            length: (Self.tightened(linkTitle) as NSString).length
        )
    }

    private var sentence: NSAttributedString {
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: leading))
        out.append(
            NSAttributedString(
                string: Self.tightened(linkTitle),
                attributes: [
                    .link: Self.href,
                    .underlineStyle: NSUnderlineStyle.single
                        .rawValue,
                ]
            )
        )
        out.append(NSAttributedString(string: trailing))
        out.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: pointSize)
            ],
            range: NSRange(location: 0, length: out.length)
        )
        return out
    }

    /// Replaces separator spaces with non-breaking spaces around breadcrumbs.
    private static func tightened(_ title: String) -> String {
        title.replacingOccurrences(
            of: " ▸ ",
            with: "\u{00A0}▸\u{00A0}"
        )
    }

    private static let href = URL(
        string: "kiwidesk-settings://cross-reference"
    )!

    final class Coordinator: NSObject, NSTextViewDelegate {
        func textView(
            _ view: NSTextView,
            clickedOnLink link: Any,
            at index: Int
        ) -> Bool {
            (view as? CaptionTextView)?.activateLink()
            return true
        }
    }
}
