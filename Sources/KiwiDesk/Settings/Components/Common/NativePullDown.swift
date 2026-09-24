import AppKit
import KiwiDeskCore
import SwiftUI

/// One row of a `NativePullDown` menu.
struct PullDownItem {
    let title: String
    var subtitle: String = ""
    var enabled = true
    var action: () -> Void = {}
}

/// A bordered action button that opens a native menu under itself
/// (#1393). A SwiftUI `Menu` drawn bordered takes its bezel from
/// the tint — accent green while the window is key, near-black
/// under the neutral ink — so a pull-down that must look like the
/// window's other text actions is a `Button` opening an `NSMenu`.
struct NativePullDown<Label: View>: View {
    /// The menu's section header, drawn above the items.
    let header: String
    /// Built at the click, so the list is current.
    let items: () -> [PullDownItem]
    @ViewBuilder let label: () -> Label
    @State private var anchor = PullDownAnchor()

    var body: some View {
        Button {
            present()
        } label: {
            label()
        }
        .settingsActionButton()
        // A Button does not say a list opens, as a Menu would.
        .accessibilityHint(L("pull_down.ax_hint", "Opens a menu."))
        // The button's own view, so the menu opens in ITS window
        // whichever window is key.
        .background(PullDownAnchorView(anchor: anchor))
    }

    private func present() {
        guard let view = anchor.view, view.window != nil else { return }
        let target = PullDownTarget(items: items())
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: header))
        for (index, item) in target.items.enumerated() {
            let entry = NSMenuItem(
                title: item.title,
                action: #selector(PullDownTarget.fire(_:)),
                keyEquivalent: ""
            )
            entry.target = target
            entry.tag = index
            entry.isEnabled = item.enabled
            // Before 14.4 a row shows its title alone.
            if !item.subtitle.isEmpty, #available(macOS 14.4, *) {
                entry.subtitle = item.subtitle
            }
            menu.addItem(entry)
        }
        // Just under the button, in the anchor's own coordinates.
        let below = CGFloat(4)
        let y =
            view.isFlipped ? view.bounds.maxY + below : -below
        withExtendedLifetime(target) {
            _ = menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: y),
                in: view
            )
        }
    }
}

/// The button's backing view, filled in by `PullDownAnchorView`.
@MainActor
private final class PullDownAnchor {
    weak var view: NSView?
}

/// A view laid behind the button at its size, handing the anchor
/// the `NSView` the menu opens from.
private struct PullDownAnchorView: NSViewRepresentable {
    let anchor: PullDownAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}

/// Holds the menu's actions while it tracks; `popUp` returns after
/// the pick, so the caller keeps it alive for exactly that long.
private final class PullDownTarget: NSObject {
    let items: [PullDownItem]

    init(items: [PullDownItem]) {
        self.items = items
    }

    @MainActor @objc func fire(_ sender: NSMenuItem) {
        items[sender.tag].action()
    }
}
