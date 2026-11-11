import AppKit

/// The live facts "Report a problem" and the log export carry
/// (#3214). Read-only; it judges nothing as saved or stored.
extension KiwiCore {
    public var problemReport: ProblemReport {
        ProblemReport(
            version: KiwiDeskVersion.displayString,
            macOS: Self.macOSVersion,
            screens: ScreenList.all.count,
            separateSpaces: tiler.applier.separateSpaces()
        )
    }

    /// `27.2.0`, from the numbers: the OS's own version string is
    /// localized, and a maintainer reads this.
    static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
            + ".\(version.patchVersion)"
    }

    /// The keep document's roots the header diffs against what an
    /// install starts from, and the ones it leaves out with the
    /// reason (`ProblemReportRootsTests` holds every root to one).
    /// The settings base is the starter's, not the bare type's, so
    /// an untouched setup lists only its screen-tuned leaves.
    static let headerDefaults: [String: JSONValue] = [
        KeepRoot.settings: StarterTuning.base().keepJSON ?? .null,
        KeepRoot.appWide: AppWideSettings().groupsJSON,
        KeepRoot.focusWrap: .string(FocusWrap.defaultMode.rawValue),
        KeepRoot.floatAutomatically: .bool(FloatGuess.enabledByDefault),
        // No default to differ from: each Space's layout is listed.
        KeepRoot.spaceModes: .object([:]),
    ]
    /// A rule list is one leaf, so a diff would print it whole.
    static let headerLeftOut: Set<String> = [
        KeepRoot.appRules, KeepRoot.floatRules,
    ]

    /// Every live value that differs from its built-in default.
    var changedSettingsLines: [String] {
        let live = keepDocument
        return Self.headerDefaults.keys.sorted().flatMap { root in
            ChangedSettings.lines(
                root: root,
                base: Self.headerDefaults[root],
                live: KeepPointer.value(at: [root], in: live)
            )
        }
    }

    /// The header an exported log opens with.
    public var logExportHeader: String {
        problemReport.logHeader(changedSettings: changedSettingsLines)
    }
}
