import KiwiDeskCore
import SwiftUI

/// One Jump to window row (#1875 ▸ Rows): the app's icon, the
/// title with its match bold, and the trailing column — its Space,
/// the way here under ⇧, and its ⌘ number while ⌘ is held.
struct JumpRowView: View {
    let match: JumpSearch.Match
    let icon: NSImage?
    let isSelected: Bool
    /// The ⌘ number this row takes, nil from row 10 on.
    let number: Int?
    let commandHeld: Bool
    let shiftHeld: Bool
    /// The current Space, drawn after the arrow; nil where ⇧
    /// changes nothing on this row.
    let wayHere: JumpRowText.Place?
    let onActivate: (_ moveHere: Bool) -> Void

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    static let height: CGFloat = 32

    private var showsNumber: Bool { commandHeld && number != nil }

    var body: some View {
        Button {
            onActivate(NSEvent.modifierFlags.contains(.shift))
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel(JumpRowText.spoken(match.entry))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(MoveHereAction(entry: match.entry, run: onActivate))
    }

    private var content: some View {
        HStack(spacing: 10) {
            iconView
            Text(JumpTitle.attributed(match))
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            trailing
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
            if showsNumber, let number {
                Text(verbatim: shiftHeld ? "⇧⌘\(number)" : "⌘\(number)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        // The ⌘ slide: the digit takes its room and the Space
        // column moves left to give it (#1875 ▸ keys).
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: showsNumber
        )
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .background(selection)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 20, height: 20)
        } else {
            Color.clear.frame(width: 20, height: 20)
        }
    }

    @ViewBuilder private var trailing: some View {
        let place = JumpRowText.place(of: match.entry)
        if isSelected, shiftHeld, let wayHere {
            JumpWayHereView(source: place, here: wayHere)
        } else if let place {
            JumpPlaceView(place: place)
        }
    }

    @ViewBuilder private var selection: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(SettingsTheme.rowSelected)
        }
    }
}

/// VoiceOver's second action on a window row; a hidden app has
/// no window to move, so its row offers none.
private struct MoveHereAction: ViewModifier {
    let entry: JumpEntry
    let run: (_ moveHere: Bool) -> Void

    func body(content: Content) -> some View {
        if entry.isHiddenApp {
            content
        } else {
            content.accessibilityAction(
                named: Text(L("jump.row.ax.move_here", "Move Here"))
            ) {
                run(true)
            }
        }
    }
}
