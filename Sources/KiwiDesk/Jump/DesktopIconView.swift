import AppKit
import KiwiDeskCore
import SwiftUI

/// One window's app icon on a Space line (#1229): a ring where it
/// is selected, an ink underline where it is its Space's
/// last-focused window, a dashed outline at 50 % where it is
/// picked up. A drag carries it — or the picked set, where it is
/// one of them.
struct DesktopIconView: View {
    let window: DesktopOverview.Window
    let image: NSImage?
    let isSelected: Bool
    let isPicked: Bool
    let isLast: Bool
    let isMatch: Bool
    /// What a drag from this icon carries.
    let dragged: [WindowID]
    let onClick: (Int, NSEvent.ModifierFlags) -> Void

    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        icon
            .frame(width: DesktopLineView.icon, height: DesktopLineView.icon)
            .opacity(isPicked ? 0.5 : isMatch ? 1 : 0.35)
            // Drawn outside the 22 pt slot, so five fit a card.
            .overlay { outline.padding(-2) }
            .overlay(alignment: .bottom) { underline }
            .contentShape(Rectangle())
            .onTapGesture {
                let event = NSApp.currentEvent
                onClick(event?.clickCount ?? 1, event?.modifierFlags ?? [])
            }
            .onDrag { DesktopsDrag.provider(dragged) }
            .accessibilityElement()
            .accessibilityLabel(
                DesktopsText.spoken(window, picked: isPicked)
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .help(window.title.isEmpty ? window.app : window.title)
    }

    @ViewBuilder private var icon: some View {
        if let image {
            Image(nsImage: image).resizable().interpolation(.high)
        } else {
            Image(systemName: "macwindow")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var outline: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        if isSelected {
            shape.strokeBorder(paint.selection, lineWidth: 2)
        } else if isPicked {
            shape.strokeBorder(
                Color.primary,
                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
            )
        }
    }

    @ViewBuilder private var underline: some View {
        if isLast {
            Capsule()
                .fill(Color.primary)
                .frame(width: 12, height: 2)
                .offset(y: 4)
                .accessibilityHidden(true)
        }
    }
}

/// The Desktops side's drag payload: window ids as plain text,
/// read back only by a Space line of the same panel.
enum DesktopsDrag {
    private static let prefix = "kiwidesk-windows:"

    static func provider(_ ids: [WindowID]) -> NSItemProvider {
        let text = prefix + ids.map { String($0.raw) }.joined(separator: ",")
        return NSItemProvider(object: text as NSString)
    }

    /// Reads the ids a drop carries and hands them on, on the main
    /// actor; false where the drop is not one of ours.
    static func receive(
        _ items: [NSItemProvider],
        _ deliver: @escaping @MainActor ([WindowID]) -> Void
    ) -> Bool {
        guard let item = items.first,
            item.canLoadObject(ofClass: NSString.self)
        else { return false }
        _ = item.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? String,
                let ids = parse(text)
            else { return }
            Task { @MainActor in deliver(ids) }
        }
        return true
    }

    static func parse(_ text: String) -> [WindowID]? {
        guard text.hasPrefix(prefix) else { return nil }
        let ids = text.dropFirst(prefix.count).split(separator: ",")
            .compactMap { UInt32($0) }.map(WindowID.init)
        return ids.isEmpty ? nil : ids
    }
}
