import AppKit
import KiwiDeskCore
import SwiftUI

/// The key panel's Shortcuts side (#2246): the active layer's
/// shortcuts, narrowed by the field, scrolling under a capped
/// height. Its layer name, scroll cue and Edit in Settings… sit in
/// the panel's footer row.
struct JumpShortcutsView: View {
    let sheet: ShortcutsSheet
    let scroll: SheetScroll
    /// The tallest the sheet stands (`JumpPanelController.sheetCap`).
    let maxHeight: CGFloat
    /// The sheet's own height, read off its layout for the
    /// footer's scroll cue.
    @Binding var contentHeight: CGFloat

    /// Whether the sheet runs past what the cap shows — the one
    /// verdict the cue reads (#1292).
    static func overflows(content: CGFloat, cap: CGFloat) -> Bool {
        content > cap
    }

    var body: some View {
        ScrollView {
            ShortcutsSheetView(
                reference: sheet.shown,
                needle: sheet.needle
            )
            .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SheetScrollDriver(scroll: scroll))
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: SheetHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
        // VoiceOver lands on the scroll view as a bare "scroll
        // area" before interacting into it (#812).
        .accessibilityLabel(JumpScope.shortcuts.panelName)
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Scrolls the enclosing scroll view by the lines or pages a key
/// asked for: the sheet scrolls with no selection to scroll to, and
/// SwiftUI on macOS 14 scrolls only to a view's id.
private struct SheetScrollDriver: NSViewRepresentable {
    let scroll: SheetScroll

    /// One ↑ ↓ press, in points.
    static let line: CGFloat = 40

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        guard scroll.serial != context.coordinator.serial else { return }
        context.coordinator.serial = scroll.serial
        guard let scrollView = view.enclosingScrollView else { return }
        let clip = scrollView.contentView
        let page = max(clip.bounds.height - Self.line, Self.line)
        let delta =
            CGFloat(scroll.lines) * Self.line + CGFloat(scroll.pages) * page
        let document = scrollView.documentView?.frame.height ?? 0
        let top = max(document - clip.bounds.height, 0)
        // Flipped content: y grows downward from the top.
        let y = min(max(clip.bounds.origin.y + delta, 0), top)
        clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
        scrollView.reflectScrolledClipView(clip)
    }

    /// Seeded with the scroll already asked, so a side re-entered
    /// replays nothing.
    func makeCoordinator() -> Coordinator {
        Coordinator(serial: scroll.serial)
    }

    final class Coordinator {
        var serial: Int
        init(serial: Int) { self.serial = serial }
    }
}
