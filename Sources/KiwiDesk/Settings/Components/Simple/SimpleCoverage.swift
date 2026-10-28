import KiwiDeskCore

/// Which census rows Simple draws (#2737): the one answer the save
/// pill reads, so a change row stays on Simple where Simple has its
/// control and leaves for Advanced where it does not.
enum SimpleCoverage {
    static func draws(_ key: SettingKey) -> Bool {
        switch key {
        case .spaces(.spacesName), .spaces(.spaceModes),
            .screens(.spacePins), .screens(.mainSpaces),
            .shortcuts(.jumpToWindow), .shortcuts(.showShortcuts),
            .shortcuts(.viewPicker), .shortcuts(.openApplications):
            return true
        default:
            return false
        }
    }
}
