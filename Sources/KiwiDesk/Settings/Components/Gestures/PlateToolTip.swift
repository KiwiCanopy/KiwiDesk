import AppKit
import SwiftUI

/// A tooltip registered by AppKit itself (`NSView.toolTip`), laid
/// over a strip picture: SwiftUI's `.help` inside the strip's
/// scroll view registered only once the window next became key, so
/// a tooltip on a card opened in a key window never showed (owner,
/// device, 2026-10-17). The view takes no clicks and no hover, so
/// the picture underneath keeps both.
struct PlateToolTip: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSView {
        let view = PassThroughView()
        view.toolTip = text
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        if view.toolTip != text { view.toolTip = text }
    }

    private final class PassThroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
