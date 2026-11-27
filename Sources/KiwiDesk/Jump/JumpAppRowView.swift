import KiwiDeskCore
import SwiftUI

/// One Applications row (#3704): the app's icon, its name with the
/// match bold, "Not open" or "Open, no windows" on the right, and its
/// ⌘ number while ⌘ is held. It draws the window row's metrics, fill
/// and hover, so the two sections read as one list.
struct JumpAppRowView: View {
    let match: JumpAppMatch
    let icon: NSImage?
    let isSelected: Bool
    var isLifted = false
    /// The ⌘ number this row takes, nil from row 10 on.
    let number: Int?
    let commandHeld: Bool
    /// A refused open showed its reason on this row.
    var refused = false
    var pulsing = false
    let onActivate: (JumpPick) -> Void
    let pickModifiers: () -> NSEvent.ModifierFlags
    var onHover: () -> Void = {}
    var onHoverEnd: () -> Void = {}

    @Environment(\.kiwiDeskReduceMotion)
    private var reduceMotion
    @Environment(\.kiwiHubPaint) private var paint

    private var showsNumber: Bool { commandHeld && number != nil }
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

    var body: some View {
        Button {
            if let pick = JumpPick.of(pickModifiers()) { onActivate(pick) }
        } label: {
            content.kiwiHubRowInk(
                paint,
                selected: isSelected,
                lifted: isLifted
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(JumpAppText.spoken(match.app))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onContinuousHover { phase in
            if case .active = phase { onHover() } else { onHoverEnd() }
        }
    }

    private var content: some View {
        HStack(spacing: JumpRowView.spacing) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Color.clear
                }
            }
            .frame(width: JumpRowView.iconSize, height: JumpRowView.iconSize)
            Text(JumpTitle.marked(match.app.name, match.range))
                .font(.body)
                .foregroundStyle(titleInk)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(
                    minWidth: JumpRowView.titleMinWidth,
                    alignment: .leading
                )
            Spacer(minLength: 12)
            trailing
                .font(.callout)
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .layoutPriority(1)
            if showsNumber, let number {
                Text(verbatim: JumpRowView.digitChord(number, false, false))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(secondaryInk)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: showsNumber
        )
        .padding(.horizontal, JumpRowView.padding)
        .frame(height: JumpRowView.height)
        .background(selection)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailing: some View {
        if refused {
            JumpRefusalView(
                text: JumpAppText.refused,
                pulsing: pulsing && !reduceMotion
            )
        } else {
            Text(JumpAppText.state(match.app)).fixedSize()
        }
    }

    @ViewBuilder private var selection: some View {
        if isSelected || isLifted {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(
                paint.fill(isSelected ? paint.selection : paint.rowHover)
            )
        }
    }
}
