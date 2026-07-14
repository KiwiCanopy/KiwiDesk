import SwiftUI

/// The bordered mini-screen a schematic draws into: a rounded
/// outline with the content clipped inside. Reused by the single-
/// frame `SchematicCanvas` and each pane of the two-frame
/// `SchematicPair`, so every frame in the family reads the same.
struct SchematicScreen<Content: View>: View {
    var width: CGFloat = LayoutSchematic.canvasWidth
    var height: CGFloat = LayoutSchematic.canvasHeight
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            content
                .padding(LayoutSchematic.inset)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.6))
        }
        .frame(width: width, height: height)
    }
}

/// The static arrow between the two panes of a *sequence* pair
/// (BSP): it reads as "then this happens", never a play button
/// (no motion — the schematics stay static, #123).
struct SchematicArrow: View {
    var body: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}

/// A single-frame schematic: one mini-screen plus a caption,
/// centred as a self-contained tile. Size defaults to the family
/// 140×96 but a mode may grow it (Scrolling draws a monitor).
///
/// Centered on purpose (the `.frame(maxWidth:.infinity)` with no
/// alignment): this is a **standalone illustration** — nothing is
/// edited on it and no control column shares its row, so it reads
/// as a figure, not a row (see design-decisions "Preview
/// alignment splits on standalone-vs-paired"). A preview that
/// *does* sit beside its controls (GapsDiagram, the Drag columns)
/// is left-aligned instead.
struct SchematicCanvas<Content: View>: View {
    var width: CGFloat = LayoutSchematic.canvasWidth
    var height: CGFloat = LayoutSchematic.canvasHeight
    let caption: String
    let axLabel: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 4) {
            SchematicScreen(width: width, height: height) {
                content
            }
            .accessibilityElement()
            .accessibilityLabel(axLabel)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A two-frame schematic. `sequence` puts a `SchematicArrow`
/// between the panes ("before → after", BSP); otherwise a plain
/// gutter reads as a side-by-side comparison. Each pane may carry
/// its own sub-caption; a shared caption sits below both.
struct SchematicPair<First: View, Second: View>: View {
    var frameWidth: CGFloat = 120
    var frameHeight: CGFloat = 96
    var sequence: Bool = true
    var firstCaption: String? = nil
    var secondCaption: String? = nil
    let caption: String
    let axLabel: String
    @ViewBuilder let first: First
    @ViewBuilder let second: Second

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                pane(first, sub: firstCaption)
                if sequence {
                    SchematicArrow()
                }
                pane(second, sub: secondCaption)
            }
            .accessibilityElement()
            .accessibilityLabel(axLabel)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func pane<C: View>(
        _ content: C,
        sub: String?
    ) -> some View {
        VStack(spacing: 3) {
            SchematicScreen(
                width: frameWidth,
                height: frameHeight
            ) {
                content
            }
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
