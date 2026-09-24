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
    @State private var frame: CGRect = .zero

    var body: some View {
        Button {
            present()
        } label: {
            label()
        }
        .settingsActionButton()
        // A Button does not say a list opens, as a Menu would.
        .accessibilityHint(L("pull_down.ax_hint", "Opens a menu."))
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { frame = proxy.frame(in: .global) }
                    .onChange(of: proxy.frame(in: .global)) { _, now in
                        frame = now
                    }
            }
        )
    }

    private func present() {
        guard let view = NSApp.keyWindow?.contentView else { return }
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
            if !item.subtitle.isEmpty {
                if #available(macOS 14.4, *) {
                    entry.subtitle = item.subtitle
                } else {
                    entry.title = item.title + " — " + item.subtitle
                }
            }
            menu.addItem(entry)
        }
        // The frame is in window coordinates, top-left origin.
        let below = CGFloat(4)
        let y =
            view.isFlipped
            ? frame.maxY + below : view.bounds.height - frame.maxY - below
        withExtendedLifetime(target) {
            _ = menu.popUp(
                positioning: nil,
                at: NSPoint(x: frame.minX, y: y),
                in: view
            )
        }
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
