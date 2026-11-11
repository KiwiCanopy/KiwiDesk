import AppKit

/// The live facts "Report a problem" and the log export carry
/// (#3214). Read-only.
extension KiwiCore {
    public var problemReport: ProblemReport {
        ProblemReport(
            version: KiwiDeskVersion.displayString,
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            screens: NSScreen.screens.count,
            separateSpaces: NSScreen.screensHaveSeparateSpaces
        )
    }

    /// The tiling and app-wide settings that differ from the
    /// built-in defaults. Rules and bindings stay out: they are
    /// lists, and a list is one leaf.
    public var changedSettingsLines: [String] {
        ChangedSettings.lines(
            root: KeepRoot.settings,
            base: TilingSettings().keepJSON,
            live: tiler.settings.keepJSON
        )
            + ChangedSettings.lines(
                root: KeepRoot.appWide,
                base: AppWideSettings().groupsJSON,
                live: appWide.groupsJSON
            )
    }

    /// The header an exported log opens with.
    public var logExportHeader: String {
        problemReport.logHeader(changedSettings: changedSettingsLines)
    }
}
