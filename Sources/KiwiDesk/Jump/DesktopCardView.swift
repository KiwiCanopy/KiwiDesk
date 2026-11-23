import AppKit
import KiwiDeskCore
import SwiftUI

/// One Desktop's card in its screen's column (#1229, #3570): its
/// title line — "Desktop N", ✓ while its screen shows it, the bound
/// profile on the right — and one line per Space, on the panel's
/// own ground (#3164). On a split screen the lines are grouped
/// under each area's name, the unfiled line last under none
/// (#3572).
struct DesktopCardView: View {
    let state: DesktopsState
    let screen: Int
    let index: Int
    let geometry: DesktopsGeometry
    /// The screen column's width (`DesktopsGeometry.columns`).
    let width: CGFloat
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    let pointer: DesktopsPointer

    @Environment(\.kiwiHubPaint) private var paint

    private var desktop: DesktopOverview.Desktop {
        state.overview.screens[screen].desktops[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesktopsGeometry.titleGap) {
            title
            lines
        }
        .padding(.horizontal, DesktopsGeometry.columnInset)
        .frame(width: width, alignment: .top)
        .overlay { ring }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DesktopsText.desktop(desktop.label))
    }

    /// The lines, each area's under its header (#3572 ruling 2),
    /// then those in no area.
    private var lines: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(desktop.areas.indices, id: \.self) { index in
                group(desktop.areas[index])
            }
            ForEach(loose, id: \.self) { line($0).id(lineID($0)) }
        }
    }

    /// The lines no area holds: every line on an unsplit screen,
    /// the unfiled line on a split one.
    private var loose: [Int] {
        desktop.spaces.indices.filter { desktop.area(of: $0) == nil }
    }

    /// One area's group: its name, then its lines. The header is no
    /// keyboard stop; VoiceOver hears the name on the group and on
    /// each line, never on the header too.
    private func group(_ area: DesktopOverview.Area) -> some View {
        VStack(alignment: .leading, spacing: DesktopsGeometry.areaGap) {
            Text(DesktopsText.area(area))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(height: DesktopsGeometry.areaHeight)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(area.lines), id: \.self) {
                    line($0).id(lineID($0))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DesktopsText.area(area))
    }

    private func lineID(_ line: Int) -> DesktopsScrollID {
        .line(DesktopsPlace(screen: screen, desktop: index, line: line))
    }

    private func line(_ line: Int) -> some View {
        DesktopLineView(
            state: state,
            place: DesktopsPlace(screen: screen, desktop: index, line: line),
            geometry: geometry,
            icons: icons,
            onPlace: onPlace,
            onWindow: onWindow,
            onMore: onMore,
            onDrop: onDrop,
            pointer: pointer
        )
    }

    private var titleTarget: JumpHover {
        .desktop(screen: screen, index: index)
    }

    /// The card's hover (#3484, ruling C2): a thin selection ring
    /// round the whole card while the pointer is on its title, the
    /// title itself staying plain; the fill stays the selection's
    /// alone (#1173).
    @ViewBuilder private var ring: some View {
        if pointer.lifts(titleTarget, selected: false) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(paint.selection, lineWidth: 1.5)
                .allowsHitTesting(false)
        }
    }

    /// The title, a button to its Desktop (#3209): the card's ring
    /// under the pointer, and `.help` as a second cue.
    private var title: some View {
        HStack(spacing: 4) {
            Text(DesktopsText.desktop(desktop.label))
                .font(.callout.weight(.semibold))
            if desktop.isShown {
                // KiwiHub's one "in use" mark, as a current chip's.
                // Own ink at full strength, never the accent
                // (#3210, #3484).
                Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .accessibilityLabel(DesktopsText.shown)
            }
            Spacer(minLength: 4)
            if let profile = desktop.profile {
                Text(profile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.tail)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 4)
        .frame(height: DesktopsGeometry.titleHeight)
        .contentShape(Rectangle())
        .onTapGesture { click() }
        .desktopsHover(titleTarget, pointer)
        .help(DesktopsText.switchTo(desktop.label))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(DesktopsText.switchTo(desktop.label))
        .accessibilityAction { click(count: 1, modifiers: []) }
    }

    /// The title is ↩ on the Desktop it names (#3209): it jumps
    /// there; during a carry it drops on the line the Desktop shows
    /// in the area KiwiHub opened over, else in its first (#3572).
    private func click() {
        let click = DesktopsClick.of(NSApp.currentEvent)
        self.click(count: click.count, modifiers: click.modifiers)
    }

    private func click(count: Int, modifiers: NSEvent.ModifierFlags) {
        onPlace(
            DesktopsPlace(
                screen: screen,
                desktop: index,
                line: desktop.landingLine
            ),
            count,
            modifiers,
            false
        )
    }
}
