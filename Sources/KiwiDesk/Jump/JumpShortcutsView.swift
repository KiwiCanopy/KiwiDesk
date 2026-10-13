import AppKit
import KiwiDeskCore
import SwiftUI

/// The key panel's Shortcuts side (#2246): the active layer's
/// shortcuts, narrowed by the field, scrolling under a capped
/// height, then the layer's name and Edit in Settings….
struct JumpShortcutsView: View {
    let sheet: ShortcutsSheet
    let scroll: SheetScroll
    /// The tallest the sheet stands (`JumpPanelController.sheetCap`).
    let maxHeight: CGFloat
    let onEdit: () -> Void
    /// The sheet's own height, read off its layout.
    @State private var contentHeight: CGFloat = 0

    /// Whether the sheet runs past what the cap shows — the one
    /// verdict the cue reads (#1292).
    static func overflows(content: CGFloat, cap: CGFloat) -> Bool {
        content > cap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            buttons
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            scrollCue
            layerLabel
            Spacer(minLength: 0)
            KeyPanelChordButton(
                title: L(
                    "shortcuts.panel.edit_in_settings",
                    "Edit in Settings…"
                ),
                chord: "⌘,",
                action: onEdit
            )
        }
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
        .padding(.vertical, 10)
    }

    /// Says the sheet continues, worded so it stays true at any
    /// scroll offset (#1292).
    @ViewBuilder private var scrollCue: some View {
        if Self.overflows(content: contentHeight, cap: maxHeight) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.down")
                    .accessibilityHidden(true)
                Text(
                    L(
                        "shortcuts.panel.scroll_hint",
                        "Scroll for more shortcuts"
                    )
                )
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    /// The active layer's name, where it is not the default one.
    @ViewBuilder private var layerLabel: some View {
        if let name = sheet.reference?.layerName,
            name != KeyLayer.defaultName
        {
            Text(name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(SettingsTheme.accent.opacity(0.2))
                )
                .frame(maxWidth: 280, alignment: .leading)
        }
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Scrolls the enclosing scroll view by the lines or pages a key
/// asked for. SwiftUI on macOS 14 scrolls only to a view's id, and
/// the sheet's two-column bands have no single row order to step.
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

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var serial = 0
    }
}
