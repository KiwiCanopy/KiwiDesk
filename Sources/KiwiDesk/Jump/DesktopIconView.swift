import AppKit
import KiwiDeskCore
import SwiftUI

/// One window's app icon on a Space line (#1229): a ring where it
/// is selected and the grey hover ground under the pointer — rows
/// fill, tiles ring (#3210) — an ink underline where it is its
/// Space's last-focused window, a dashed outline at 50 % where it
/// is picked up. A drag carries it — or the picked set, where it is
/// one of them.
struct DesktopIconView: View {
    let window: DesktopOverview.Window
    /// The icon's side, from the line height (`DesktopsGeometry.icon`).
    let size: CGFloat
    let image: NSImage?
    let isSelected: Bool
    let isPicked: Bool
    let isLast: Bool
    let isMatch: Bool
    /// Whether the icon's line wears a fill (selected or a drop
    /// target): the hover then lifts in the line's ink, not `rowHover`.
    let onFill: Bool
    /// What a drag from this icon carries.
    let dragged: [WindowID]
    let pointer: DesktopsPointer
    let onClick: (Int, NSEvent.ModifierFlags) -> Void

    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        icon
            .frame(width: size, height: size)
            .opacity(isPicked ? 0.5 : isMatch ? 1 : 0.35)
            // Drawn outside the slot, so slots keep their count.
            .background { ground.padding(-2) }
            .overlay { outline.padding(-2) }
            .overlay(alignment: .bottom) { underline }
            .contentShape(Rectangle())
            .onTapGesture {
                let click = DesktopsClick.of(NSApp.currentEvent)
                onClick(click.count, click.modifiers)
            }
            .onDrag { DesktopsDrag.provider(dragged) }
            .desktopsHover(.window(window.id), pointer)
            .accessibilityElement()
            .accessibilityAction { onClick(1, []) }
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

    @ViewBuilder private var ground: some View {
        if pointer.lifts(.window(window.id), selected: isSelected) {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    onFill
                        ? AnyShapeStyle(
                            paint.selectionInk.opacity(paint.filledLift)
                        )
                        : paint.fill(paint.rowHover)
                )
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
