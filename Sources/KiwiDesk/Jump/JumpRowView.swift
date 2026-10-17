import KiwiDeskCore
import SwiftUI

/// One Jump to window row (#1875 ▸ Rows): the app's icon, the
/// title with its match bold, and the trailing column — its Space,
/// the way here under ⇧, and its ⌘ number while ⌘ is held.
struct JumpRowView: View {
    let match: JumpSearch.Match
    let icon: NSImage?
    let isSelected: Bool
    /// The pointer lifts this row, grey (#2365).
    var isLifted = false
    /// The ⌘ number this row takes, nil from row 10 on.
    let number: Int?
    let commandHeld: Bool
    let shiftHeld: Bool
    /// The current Space, drawn after the arrow; nil where ⇧
    /// changes nothing on this row.
    let wayHere: JumpRowText.Place?
    let onActivate: (_ moveHere: Bool) -> Void
    /// The pointer moved over this row.
    var onHover: () -> Void = {}
    var onHoverEnd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// The key panels' row (#2229 ▸ shared panel style): a
    /// `.body` line with room above and below.
    static let height: CGFloat = 34
    static let iconSize: CGFloat = 22
    /// The row's padding inside its selection.
    static let padding: CGFloat = 10
    static let spacing: CGFloat = 10

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
    /// ⇧ alone moves the selected row (⇧↩); ⇧⌘ reaches every
    /// numbered row through its digit, so each shows its way here.
    var showsWayHere: Bool {
        shiftHeld && wayHere != nil
            && (isSelected || (commandHeld && number != nil))
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
        .onContinuousHover { phase in
            if case .active = phase { onHover() } else { onHoverEnd() }
        }
    }

    private var content: some View {
        HStack(spacing: Self.spacing) {
            iconView
            Text(JumpTitle.attributed(match))
                .font(.body)
                .foregroundStyle(titleInk)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            trailing
                .font(.callout)
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
            if showsNumber, let number {
                Text(verbatim: shiftHeld ? "⇧⌘\(number)" : "⌘\(number)")
                    .font(.callout.monospacedDigit())
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
        .padding(.horizontal, Self.padding)
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
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(SettingsTheme.accent)
        } else if isLifted {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(SettingsTheme.chipRest)
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
