import SwiftUI

/// A line a recorder states under its row (#3553): why the row
/// would not fire as drawn, or what the last press left. The row
/// draws it across its width, so a long line never widens the
/// recorder's trailing column into the row's label.
enum RecorderCaption: Equatable {
    /// A dead row's sentence, the badge's words (#1126).
    case dead(String)
    /// An either-side row a sided row narrows (#3256), with the
    /// other row's scroll target for its Go to.
    case narrowing(drawn: String, spoken: String, row: String)
    /// A single modifier tap waiting out the gap (#1872).
    case tapAgain(String)
    /// A single tap the field just recorded (#3257).
    case tapOnce(drawn: String, spoken: String)
    /// A gesture chord Core refused, announced on its press.
    case refused(String)
    /// A gesture's Hyper chord while no Hyper key is set.
    case dormant(String)
}

private struct RecorderCaptionSlotKey: EnvironmentKey {
    static var defaultValue: Binding<[RecorderCaption]>? { nil }
}

extension EnvironmentValues {
    /// Where the recorder below puts its captions, set by the row
    /// hosting it; nil draws them in the recorder's own column.
    var recorderCaptionSlot: Binding<[RecorderCaption]>? {
        get { self[RecorderCaptionSlotKey.self] }
        set { self[RecorderCaptionSlotKey.self] = newValue }
    }
}

extension View {
    /// Hands `captions` to the hosting row's slot while the
    /// recorder is mounted; with no slot it does nothing.
    func publishesCaptions(
        _ captions: [RecorderCaption],
        to slot: Binding<[RecorderCaption]>?
    ) -> some View {
        onChange(of: captions, initial: true) { _, now in
            slot?.wrappedValue = now
        }
        .onDisappear { slot?.wrappedValue = [] }
    }
}

/// The captions as lines, in order. Needs the section's
/// `RecorderCoordinator` for the narrowing's Go to.
struct RecorderCaptionLines: View {
    let captions: [RecorderCaption]

    @EnvironmentObject private var coordinator: RecorderCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(captions.indices, id: \.self) { index in
                line(captions[index])
            }
        }
    }

    @ViewBuilder private func line(_ caption: RecorderCaption) -> some View {
        switch caption {
        case .dead(let sentence):
            // The record button's value and the badge speak it.
            deadLine(sentence).accessibilityHidden(true)
        case .narrowing(let drawn, let spoken, let row):
            narrowing(drawn: drawn, spoken: spoken, row: row)
        case .tapAgain(let hint):
            plain(hint)
        case .tapOnce(let drawn, let spoken):
            plain(drawn).accessibilityLabel(spoken)
        case .refused(let sentence):
            // A press to retry: the button's flash and the
            // announcement carry the moment, so no triangle.
            Text(sentence)
                .font(.caption)
                .foregroundStyle(SettingsTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        case .dormant(let sentence):
            plain(sentence)
        }
    }

    /// `KeyRecorderRejectionRow`'s shape: the triangle is the cue
    /// beside the red (WCAG 1.4.1), on a wrapped line's first.
    private func deadLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(SettingsTheme.danger)
    }

    private func plain(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func narrowing(
        drawn: String,
        spoken: String,
        row: String
    ) -> some View {
        Group {
            if coordinator.scrollsInPlace {
                LinkedCaption(
                    leading: drawn + " ",
                    linkTitle: KeyRecorderField.goToTitle,
                    trailing: "",
                    navigate: { coordinator.scrollTarget = row }
                )
            } else {
                plain(drawn)
            }
        }
        // The glyphs read as nothing; one element speaks the words
        // and keeps the Go to, where drawn, as its action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .modifier(
            GoToAction(
                title: KeyRecorderField.goToTitle,
                live: coordinator.scrollsInPlace
            ) { coordinator.scrollTarget = row }
        )
    }
}

/// The caption's Go to for VoiceOver, offered only where the page
/// scrolls to the other row.
private struct GoToAction: ViewModifier {
    let title: String
    let live: Bool
    let go: () -> Void

    func body(content: Content) -> some View {
        if live {
            content.accessibilityAction(named: title, go)
        } else {
            content
        }
    }
}
