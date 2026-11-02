import KiwiDeskCore
import SwiftUI

/// One Jump to window row (#1875 ▸ Rows): the app's icon, the
/// title with its match bold, and the trailing column — its Space,
/// the way here under ⇧ or ⌥, and its ⌘ number while ⌘ is held.
struct JumpRowView: View {
    let match: JumpSearch.Match
    let icon: NSImage?
    let isSelected: Bool
    /// The pointer lifts this row, grey (#2365).
    var isLifted = false
    /// The row ⇧ alone acts on (`JumpHover.shiftRow`, #2808).
    let ownsShift: Bool
    /// The row ⌥ acts on, by the same rule (#2885).
    var ownsOption = false
    /// The ⌘ number this row takes, nil from row 10 on.
    let number: Int?
    let commandHeld: Bool
    let shiftHeld: Bool
    var optionHeld = false
    /// The current Space, drawn after the arrow; nil where ⇧
    /// changes nothing on this row.
    let wayHere: JumpRowText.Place?
    /// The current Space, where Swap here trades this row's window
    /// across Spaces; nil where it trades none (#2885).
    var waySwap: JumpRowText.Place?
    let onActivate: (JumpPick) -> Void
    /// The pointer moved over this row.
    var onHover: () -> Void = {}
    var onHoverEnd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    @Environment(\.kiwiHubPaint) private var paint

    /// The key panels' row (#2229 ▸ shared panel style): a
    /// `.body` line with room above and below.
    static let height: CGFloat = 34
    static let iconSize: CGFloat = 22
    /// The row's padding inside its selection.
    static let padding: CGFloat = 10
    static let spacing: CGFloat = 10
    /// The title's floor: below it a screen's name shortens
    /// instead (#2792).
    static let titleMinWidth: CGFloat = 120

    private var showsNumber: Bool { commandHeld && number != nil }
    /// The selection's fill is fixed in both modes, so its inks are.
    private var titleInk: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(paint.selectionInk) }
        if isLifted, let ink = paint.hoverInk { return AnyShapeStyle(ink) }
        return AnyShapeStyle(.primary)
    }
    private var secondaryInk: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(paint.selectionInkSecondary)
            : AnyShapeStyle(.secondary)
    }
    /// ⇧ alone acts on one row (`ownsShift`); ⇧⌘ reaches every
    /// numbered row through its digit, so each shows its way here.
    var showsWayHere: Bool {
        shiftHeld && !optionHeld && wayHere != nil
            && (ownsShift || (commandHeld && number != nil))
    }
    /// ⌥ or ⇧⌥ draws the two-way route on its one row.
    var showsWaySwap: Bool { optionHeld && ownsOption && waySwap != nil }
    /// The route ⌥ draws where it has one, else ⇧'s.
    private var swapRoute: Bool { optionHeld && waySwap != nil }
    private var showsRoute: Bool {
        swapRoute ? showsWaySwap : showsWayHere
    }

    var body: some View {
        Button {
            if let pick = JumpPick.of(NSEvent.modifierFlags) {
                onActivate(pick)
            }
        } label: {
            content.kiwiHubRowInk(
                paint,
                selected: isSelected,
                lifted: isLifted
            )
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
                .frame(minWidth: Self.titleMinWidth, alignment: .leading)
            Spacer(minLength: 12)
            trailing
                .font(.callout)
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
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
            value: [showsNumber, showsRoute]
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
        // One view whichever route it draws, so ⌥ re-frames the
        // route in place rather than swapping the column.
        if let target = swapRoute ? waySwap : wayHere {
            JumpWayHereView(
                source: place,
                here: target,
                expanded: showsRoute,
                frame: swapRoute
                    ? JumpRowText.waySwapFrame : JumpRowText.wayHereFrame
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
            .fill(paint.fill(paint.selection))
        } else if isLifted {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(paint.fill(paint.rowHover))
        }
    }
}

/// VoiceOver's Move Here and Swap Here on a window row; a hidden
/// app has no window to move or swap, so its row offers neither.
private struct MoveHereAction: ViewModifier {
    let entry: JumpEntry
    let run: (JumpPick) -> Void

    func body(content: Content) -> some View {
        if entry.isHiddenApp {
            content
        } else {
            content
                .accessibilityAction(
                    named: Text(L("jump.row.ax.move_here", "Move Here"))
                ) {
                    run(.moveHere)
                }
                .accessibilityAction(
                    named: Text(L("jump.row.ax.swap_here", "Swap Here"))
                ) {
                    run(.swapHere)
                }
        }
    }
}
