import AppKit
import KiwiDeskCore
import SwiftUI

/// One open of a license text over About; a fresh id per open
/// (#843).
struct LicenseRequest: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

/// A license text in KiwiDesk itself (#3286): a second read-only
/// sheet stacked on About, the #859 shape — Return and Escape both
/// put away this sheet alone. The text stays English, as shipped;
/// the title is localized.
struct LicenseSheet: View {
    let request: LicenseRequest
    let onDone: () -> Void

    /// About 80 columns of the 11 pt monospaced body, plus the
    /// text view's insets and scroller.
    static let size = CGSize(width: 620, height: 560)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.title)
                .font(.headline)
                .foregroundStyle(SettingsTheme.ink)
                .accessibilityAddTraits(.isHeader)
            LicenseTextView(text: request.text)
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsTheme.chipRadius)
                        .strokeBorder(SettingsTheme.hairline, lineWidth: 1)
                )
            HStack {
                Spacer()
                Button(doneLabel, action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .settingsActionButton()
            }
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
        .frame(width: Self.size.width, height: Self.size.height)
        .background(SettingsTheme.card)
        .background(escapeRoute)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(request.title)
    }

    private var doneLabel: String {
        L("common.done", "Done")
    }

    /// Escape as a hidden `.cancelAction` button (#859), as About's.
    private var escapeRoute: some View {
        Button(doneLabel, action: onDone)
            .keyboardShortcut(.cancelAction)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// The text itself: a read-only, selectable `NSTextView` in its
/// scroll view, monospaced at 11 pt, with the find bar on ⌘F.
struct LicenseTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = LicenseTextFinding.scrollableTextView()
        (scroll.documentView as? NSTextView)?.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView,
            view.string != text
        else { return }
        view.string = text
    }
}

/// The text view's setup, and its find chords: the hidden main
/// menu has no Find item, so the view takes ⌘F, ⌘G and ⇧⌘G itself,
/// through the find bar's own actions (gui.md ▸ SwiftUI traps).
@MainActor
enum LicenseTextFinding {
    static func scrollableTextView() -> NSScrollView {
        let scroll = NSScrollView()
        let view = FindingTextView(frame: .zero)
        view.minSize = .zero
        view.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.isEditable = false
        view.isSelectable = true
        view.usesFindBar = true
        view.isIncrementalSearchingEnabled = true
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 8, height: 8)
        view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        view.textColor = .labelColor
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = view
        return scroll
    }

    /// The find action a chord asks for, nil for any other chord.
    static func action(
        key: String?,
        modifiers: NSEvent.ModifierFlags
    ) -> NSTextFinder.Action? {
        // Caps Lock and the like never change which chord it is.
        let mods = modifiers.intersection(
            [.command, .shift, .option, .control]
        )
        switch (key?.lowercased(), mods) {
        case ("f", [.command]): return .showFindInterface
        case ("g", [.command]): return .nextMatch
        case ("g", [.command, .shift]): return .previousMatch
        default: return nil
        }
    }

    private final class FindingTextView: NSTextView {
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard
                let action = LicenseTextFinding.action(
                    key: event.charactersIgnoringModifiers,
                    modifiers: event.modifierFlags
                )
            else { return super.performKeyEquivalent(with: event) }
            let sender = NSMenuItem()
            sender.tag = action.rawValue
            performFindPanelAction(sender)
            return true
        }
    }
}
