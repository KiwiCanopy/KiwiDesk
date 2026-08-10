import Foundation
import Testing

@testable import KiwiDesk

/// The Home shell's surfacing branches and one-line wiring
/// decisions (#678 turn 9), pinned by needles on the USE sites
/// — the Monitors lesson, three times paid for: a surfacing
/// gate ends in an `if` inside a `body`, and every other guard
/// passes whether or not that `if` was ever written. Comments
/// are stripped (a comment quoting a key must not stand in for
/// a call site) and whitespace squashed, and each needle names
/// the branch TOGETHER with what it draws or decides.
///
/// Stated limit: these are existence pins, not behavior — the
/// behavior halves live in `HomeCardOrderTests`,
/// `HomeCardContentTests` and `SettingsModeNavigationTests`.
/// What only these can see is a branch or a wiring line being
/// deleted whole with the suite green
/// (`ZOrderSequenceWiringTests` is the precedent).
@Suite("Home surfacing branches")
struct HomeSurfacingTests {
    private static let root = SourceScan.repoRoot(
        from: #filePath
    )

    /// file (under Sources/KiwiDesk) → needles that must
    /// survive in its comment-stripped, whitespace-squashed
    /// source.
    private static let needles: [String: [String]] = [
        "Settings/SettingsView.swift": [
            // Home mounts exactly when no area is pushed.
            "ifselection==nil{HomeScreen(model:model)",
            // Escape pops an area back to Home.
            ".onExitCommand{ifselection!=nil{selection=nil}}",
            // A link into a Power-User-only area switches the mode
            // before landing.
            "ensureModeAdmits(destination)selection=destination",
            // The mode-reveal window reaches both panes (#760):
            // the environment mounts above the Home/detail
            // branch, from the model's one timeline.
            ".environment(\\.settingsModeReveal,"
                + "model.modeRevealActive)",
            // The save pill FLOATS over the content (#678
            // redesign spec; owner overturned the docked
            // footer 2026-08-09) —
            // an overlay, so it reserves no layout space, and
            // it re-centres on the content column while a
            // panel is open.
            ".overlay(alignment:.bottom){"
                + "SettingsFooter(model:model)",
            "x:panelVisible?-SettingsTheme.panelWidth/2:0",
            // The search mode-switch notice DRAWS when set
            // (#678 4c) — needle through the branch body: a
            // consult that never mounts the strip would leave
            // the flip unannounced with every test green.
            "ifletnotice=model.searchModeNotice{"
                + "SettingsSearchNotice(text:notice)",
        ],
        "Settings/SettingsView+Detail.swift": [
            // The two-column detail consults the ONE offer set
            // and DRAWS the panel through it (#678 redesign
            // spec) — needle through the branch body, the
            // Monitors lesson.
            "ifpanelVisible,letdestination=model.destination"
                + "{SettingsTheme.hairline.frame(width:1)"
                + "SettingsDetailPanel("
        ],
        "Settings/SettingsFooter.swift": [
            // The pill exists only while the draft does —
            // grey-don't-hide's one exempted surface here.
            "ifhasWork{pill"
        ],
        "Settings/SettingsFooter+Unsaved.swift": [
            // The count line is a BUTTON only while the draft
            // has attributed rows — at zero there is no list
            // to open, so it stays plain text — and its N is
            // the ROW COUNT of the very list the popover
            // renders, one source, so sentence and list
            // cannot disagree (owner 2026-08-10: the settings
            // count said "1" over a three-row family).
            "letrows=SettingsDiffRowSource.rows(for:model)",
            "if!rows.isEmpty{countButton(count:rows.count)",
            // The button's popover renders the one diff-rows
            // renderer (turn 9's third view of the draft, moved
            // from the header chip 2026-08-10) — needle through
            // the popover body so a count that stops opening
            // the list reds.
            "SettingsDiffRowsView("
                + "rows:SettingsDiffRowSource.rows(for:model)",
        ],
        "Settings/SettingsView+Reveal.swift": [
            // A search hit into a Power-User-only area switches
            // the mode BEFORE landing — one needle through the
            // whole run (flip, announce, land), so the ORDER
            // stays pinned, not just each statement's existence.
            "ensureModeAdmits(resolved.destination)"
                + "ifletarmedNotice,wasSimple,"
                + "model.settingsMode==.powerUser{"
                + "model.noteSearchModeSwitch(armedNotice)}"
                + "model.destination=resolved.destination",
            // The reveal CONSUMES the armed notice
            // unconditionally (a refused request must not leave
            // a stale arm)…
            "letarmedNotice=model.nav.pendingModeNotice"
                + "model.nav.pendingModeNotice=nil",
        ],
        "Settings/SettingsHeaderBar.swift": [
            // The pushed form draws the back chip, the Home
            // form the identity.
            "ifletdestination{backChipText(destination.title)",
            // The segment is the one EXPLICIT flip — the entry
            // point that washes what the flip inserts (#760).
            // `ensureModeAdmits` stays on `setSettingsMode`.
            "model.flipSettingsMode($0,reduceMotion:reduceMotion)",
            // The search wiring is one-line-wiring territory
            // (architect review 2026-08-10): swap any closure
            // for a stub and Places, the value column or the
            // notice dies with every suite green. Needles on
            // the USE sites.
            "context:searchContext",
            "value:{[weakmodel]keyin"
                + "model?.searchValue(for:key)}",
            "armModeNotice:{model.nav.pendingModeNotice=$0}",
        ],
        "Settings/HomeScreen.swift": [
            // The 14c banner is drawn, not merely computed.
            "iffirstRunVisible{HomeFirstRunBanner("
        ],
        "Settings/HomeCard.swift": [
            // The conflict shout is drawn on the card.
            "ifletshout{shoutBadge(shout)}",
            // A preview card DRAWS its preview — the needle
            // runs through the branch body, so a consult whose
            // binding goes unrendered fails it (re-review
            // 2026-08-04: the consult-only form passed with
            // the body emptied).
            "ifletpreview=HomeCardPreview.preview("
                + "for:destination,model:model){preview}",
            // A plated card DRAWS its desktop plate (#786) —
            // same branch-body form, same reason — and the
            // plate mounts ABOVE the washed title band, which
            // keeps it outside the reveal wash by structure.
            "ifletplate=HomeCardPlate.plate("
                + "for:destination,model:model){plate}",
        ],
        "Settings/SettingsSearchRow.swift": [
            // Enrichment and the mode tag are surfacing
            // branches: consulting the closure is not drawing
            // its answer.
            "ifletshownValue{Text(shownValue)",
            "ifswitchesMode{modeTag}",
        ],
        "Settings/SettingsModel+EditTarget.swift": [
            // A dirty draft reaching a clean transition
            // retires the first-run banner (through the
            // injected-domain seam).
            "ifisDirty{"
                + "HomeFirstRunState.retire(preferences)}"
        ],
        "Settings/SettingsWindowController.swift": [
            // Home is the entry point on every open.
            "model.destination=nil"
        ],
        "Settings/HomeFirstRunBanner.swift": [
            // Dismiss retires permanently and unmounts.
            "HomeFirstRunState.retire(model.preferences)"
                + "visible=false"
        ],
        "AppDelegate+Onboarding.swift": [
            // The tour's close seeds the banner beside the
            // discovery flag.
            "OnboardingDiscovery.markShown()"
                + "HomeFirstRunState.seed(.standard)"
        ],
        "AppDelegate.swift": [
            // "Show me around" reaches the real replay.
            "created.setShowTour{[weakself]in"
                + "self?.replayOnboardingTour()}"
        ],
    ]

    @Test("every surfacing branch is drawn where it decides")
    func branchesAreDrawn() throws {
        for (path, wanted) in Self.needles {
            let url = Self.root
                .appendingPathComponent("Sources/KiwiDesk")
                .appendingPathComponent(path)
            let raw = try String(
                contentsOf: url,
                encoding: .utf8
            )
            #expect(!raw.isEmpty)
            let squashed = SourceScan.stripComments(raw)
                .split(whereSeparator: \.isWhitespace)
                .joined()
            for needle in wanted {
                #expect(
                    squashed.contains(needle),
                    Comment(
                        rawValue:
                            "\(path) lost its branch or wiring: "
                            + needle
                    )
                )
            }
        }
    }
}
