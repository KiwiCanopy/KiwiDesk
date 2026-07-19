import KiwiDeskCore
import SwiftUI

/// The Bars tab's two-editor switch as a recognition control
/// (ui-designer 2026-07-19): QA found the plain segmented
/// picker read as inert chrome, so users never realized two
/// bars exist. The Displays-pane pattern instead — each option
/// is a small schematic of the bar it opens (a row of app
/// icons vs numbered space tabs) with its name below, selected
/// state as an accent ring. Static mocks, not config-driven:
/// the chip answers "which bar is this," the editor's own live
/// preview answers "what does mine look like."
struct BarEditorPicker: View {
    @Binding var selection: BarsSection.Editor

    var body: some View {
        HStack(spacing: 12) {
            chip(
                .appBar,
                title: L("bars.switch.app_bar", "App Bar")
            ) {
                appBarMock
            }
            chip(
                .spaceBar,
                title: L("bars.switch.space_bar", "Space Bar")
            ) {
                spaceBarMock
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("bars.switch", "Bar"))
    }

    private func chip<Mock: View>(
        _ editor: BarsSection.Editor,
        title: String,
        @ViewBuilder mock: () -> Mock
    ) -> some View {
        let selected = selection == editor
        return Button {
            selection = editor
        } label: {
            VStack(spacing: 6) {
                mock()
                    .frame(height: 24)
                Text(title)
                    .font(.callout)
                    .fontWeight(selected ? .semibold : .regular)
                    .lineLimit(1)
            }
            .frame(width: 132)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selected
                            ? Color.accentColor : .clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(
            selected ? [.isSelected] : []
        )
    }

    /// A row of app-icon tiles, one ringed active.
    private var appBarMock: some View {
        HStack(spacing: 4) {
            mockTile(symbol: "globe")
            mockTile(symbol: "terminal", active: true)
            mockTile(symbol: "envelope")
        }
    }

    /// Numbered space tabs, the first on the accent plate.
    private var spaceBarMock: some View {
        HStack(spacing: 4) {
            mockTab("1", active: true)
            mockTab("2")
            mockTab("3")
        }
    }

    private func mockTile(
        symbol: String,
        active: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            Color.accentColor,
                            lineWidth: 1.5
                        )
                }
            }
    }

    private func mockTab(
        _ number: String,
        active: Bool = false
    ) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                active
                    ? Color.accentColor.opacity(0.25)
                    : Color.secondary.opacity(0.18)
            )
            .frame(width: 22, height: 22)
            .overlay {
                Text(number)
                    .font(
                        .system(size: 10, weight: .semibold)
                    )
                    .foregroundStyle(
                        active
                            ? Color.accentColor
                            : Color.secondary
                    )
            }
    }
}
