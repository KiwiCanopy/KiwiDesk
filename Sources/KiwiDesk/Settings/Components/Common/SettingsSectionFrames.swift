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

extension EnvironmentValues {
    /// Whether section cards report `SettingsSectionFrames`.
    var measuresSectionFrames: Bool {
        get { self[MeasuresSectionFramesKey.self] }
        set { self[MeasuresSectionFramesKey.self] = newValue }
    }
}
