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

    /// Rows the size of the search field, at Spotlight's scale
    /// (#1875): a `.title` line with room above and below.
    static let height: CGFloat = 56
    static let iconSize: CGFloat = 36
    /// The selection's inset from the panel's sides; its radius is
    /// concentric with the panel's corners.
    static let selectionInset: CGFloat = 10
    static var selectionRadius: CGFloat {
        JumpPanelView.cornerRadius - selectionInset
    }

    private var showsNumber: Bool { commandHeld && number != nil }
    /// The accent fill is fixed in both modes, so its inks are.
    private var titleInk: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(SettingsTheme.accentInk)
            : AnyShapeStyle(.primary)
    }
    private var secondaryInk: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(SettingsTheme.accentInkSecondary)
            : AnyShapeStyle(.secondary)
    }
    private var showsWayHere: Bool {
        isSelected && shiftHeld && wayHere != nil
    }

    var body: some View {
        Button {
            onActivate(NSEvent.modifierFlags.contains(.shift))
        } label: {
            content
        }
        .buttonStyle(.plain)
        // The panel's keys move the list and the field keeps the
        // focus; a row taking it drew a focus ring on row 1.
        .focusable(false)
        .accessibilityLabel(JumpRowText.spoken(match.entry))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .modifier(MoveHereAction(entry: match.entry, run: onActivate))
    }

    private var content: some View {
        HStack(spacing: 12) {
            iconView
            Text(JumpTitle.attributed(match))
                .font(.title)
                .foregroundStyle(titleInk)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            trailing
                .font(.title2)
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
            if showsNumber, let number {
                Text(verbatim: shiftHeld ? "⇧⌘\(number)" : "⌘\(number)")
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(secondaryInk)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        // The ⌘ slide: the digit takes its room and the Space
        // column moves left to give it (#1875 ▸ keys); ⇧'s way
        // here takes its room the same way, alone or with ⌘.
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: [showsNumber, showsWayHere]
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
                .frame(width: Self.iconSize, height: Self.iconSize)
        } else {
            Color.clear.frame(width: Self.iconSize, height: Self.iconSize)
        }
    }

    @ViewBuilder private var trailing: some View {
        let place = JumpRowText.place(of: match.entry)
        if let wayHere {
            JumpWayHereView(
                source: place,
                here: wayHere,
                expanded: showsWayHere
            )
        } else if let place {
            JumpPlaceView(place: place)
        }
    }

    @ViewBuilder private var selection: some View {
        if isSelected {
            RoundedRectangle(
                cornerRadius: Self.selectionRadius,
                style: .continuous
            )
            .fill(SettingsTheme.accent)
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
