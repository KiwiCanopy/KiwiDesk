import SwiftUI

/// Section card frames keyed by their catalog anchor id, reported
/// only where a page opts in through `measuresSectionFrames`
/// (#1520), in the coordinate space that page names `space`.
struct SettingsSectionFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static let space = "settingsSectionFrames"

    static func reduce(
        value: inout [String: CGRect],
        nextValue: () -> [String: CGRect]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct MeasuresSectionFramesKey: EnvironmentKey {
    static let defaultValue = false
}

extension View {
    /// Opts a page's scroll view in: its section cards report
    /// their frames, in the space this names on it.
    func mapsSectionFrames() -> some View {
        environment(\.measuresSectionFrames, true)
            .coordinateSpace(name: SettingsSectionFrames.space)
    }
}

extension View {
    /// Reports this card's frame under `control`'s anchor id, where
    /// the page measures (#1520).
    func reportsSectionFrame(_ control: SettingsControl) -> some View {
        background { SectionFrameReport(control: control) }
    }
}

/// The card's frame keyed by the same id its anchor takes, so a
/// page mapping its sections names each by one key (#1520).
private struct SectionFrameReport: View {
    let control: SettingsControl
    @Environment(\.measuresSectionFrames)
    private var measuresFrames

    var body: some View {
        if measuresFrames {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: SettingsSectionFrames.self,
                    value: [
                        control.id: proxy.frame(
                            in: .named(SettingsSectionFrames.space)
                        )
                    ]
                )
            }
        }
    }
}

extension EnvironmentValues {
    /// Whether section cards report `SettingsSectionFrames`.
    var measuresSectionFrames: Bool {
        get { self[MeasuresSectionFramesKey.self] }
        set { self[MeasuresSectionFramesKey.self] = newValue }
    }
}
