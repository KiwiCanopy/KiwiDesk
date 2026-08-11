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
            // The measured band is published ONCE, from the
            // shell's own geometry: every responsive decision
            // below reads it from the environment rather than
            // measuring again.
            "letwidth=SettingsWidthClass.of(width:geo.size.width)"
                + "shell(width).environment(\\.settingsWidth,width)",
            // Widening back into the docked band retires the
            // card's per-mount answer — a one-line `onChange`
            // whose deletion nothing else notices, and whose
            // absence is what both docs would then describe
            // wrongly (architecture review, 2026-08-11).
            ".onChange(of:width){_,nowin"
                + "ifnow.docksPanel{previewShown=nil}}",
        ],
        "Settings/SettingsView+Chrome.swift": [
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
            // panel is DOCKED. Below the row breakpoint the
            // overlay is empty and the bar mounts as a
            // sibling instead (17a): both halves are needled,
            // because either one alone leaves a width band
            // with no save affordance at all.
            "x:panelDocked(width)?-SettingsTheme.panelWidth/2:0",
            "ifwidth.docksSavePill{"
                + "SettingsFooter(model:model,docked:true)}",
            // The detached preview and its offer are drawn
            // where the band decides them (17a) — needles
            // through the overlay bodies, since a consult that
            // mounts nothing leaves every narrow window with
            // no preview and the whole suite green.
            // ONE needle over both overlays IN SEQUENCE: the
            // order is the fix (`.overlay` composes outward, so
            // the card must be applied after the pill or the
            // pill covers it and eats its grab bar's clicks),
            // and two independent strings could not see a swap
            // (guard-prover, 2026-08-11).
            ".overlay(alignment:.bottomTrailing){"
                + "showPreviewOffer(width)}"
                + ".overlay(alignment:.bottom){"
                + "if!width.docksSavePill{"
                + "SettingsFooter(model:model)",
            ".overlay(alignment:.topTrailing){"
                + "detachedPreview(width)}",
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
            "ifpanelDocked(width),letdestination=model.destination"
                + "{SettingsTheme.hairline.frame(width:1)"
                + "SettingsDetailPanel("
        ],
        "Settings/SettingsFloatingPanel.swift": [
            // The gesture is declared in the view that takes
            // the preview as an already-built child, never in
            // the one that constructs it (gui.md ▸ responsive
            // width). Moving `@GestureState` up is a one-line
            // edit that reintroduces a per-frame rebuild of a
            // draft diff and a schematic, and nothing but this
            // needle would notice — the symptom is stutter
            // under a pointer.
            // ONE needle spanning the declaration and its
            // owner, because the file-wide match this started
            // as was satisfied by the property existing
            // ANYWHERE in the file — including inside
            // `SettingsFloatingPanel`, which is the violation
            // (guard-prover, 2026-08-11: the mutation this
            // comment describes stayed green).
            "privatestructMovableCard<Content:View>:View{"
                + "letbounds:CGSizeletclose:()->Void"
                + "@Stateprivatevarmoved:CGSize=.zero"
                + "@GestureStateprivatevardragging:CGSize=.zero"
                + "@ViewBuilderletcontent:Content"
        ],
        "Settings/SettingsView+Preview.swift": [
            // The card mounts through the band predicate, and
            // its close is per-mount state — never a stored
            // preference (`DetailPanelTests` owns that half).
            "ifdetachedPreviewShown(width),"
                + "letdestination=model.destination",
            "close:{previewShown=false}",
            // A new area gets a new card: without the key the
            // structural position is identical across a
            // destination change and the card's travel
            // survives it.
            ".id(destination)",
            // The offer exists exactly where the card does
            // not: 17a drops the preview's COLUMN, never the
            // preview, so an area that has one always has a
            // way to it. Both branches read the ONE form
            // derivation, which is what makes "exactly one of
            // three" provable at all.
            "ifpreviewForm(width)==.offer{"
                + "Button{previewShown=true}label:{"
                + "showPreviewLabel}",
            "guardpanelOfferedelse{returnnil}"
                + "returnSettingsPreviewForm.at("
                + "width,shown:previewShown)",
        ],
        "Settings/SettingsFooter.swift": [
            // The bar exists only while the draft does —
            // grey-don't-hide's one exempted surface here —
            // and its two forms are one view (17a): same
            // verbs, different physics.
            "ifhasWork{bar",
            "ifdocked{dockedBar}else{pill}",
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
            // form the identity — and below the chrome
            // breakpoint both yield the row to the opened
            // search field (17a), which is the one thing that
            // step costs.
            "ifletdestination{backChipif!titleYields{"
                + "Text(destination.title)",
            "elseif!titleYields{identity}",
            "privatevartitleYields:Bool{"
                + "width.collapsesChrome&&searchExpanded}",
            // And the flag retires when the window leaves the
            // collapsed band, so a narrowing window does not
            // re-enter it with the field already open and the
            // title yielded to nobody. One line, no other net
            // (architecture review, 2026-08-11).
            ".onChange(of:width){_,nowin"
                + "if!now.collapsesChrome{searchExpanded=false}}",
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
            // A navigation is a new search context: the field
            // remounts on the destination, clearing the query
            // and closing the panel — without this, restored
            // focus re-opens stale suggestions after every
            // push/pop (owner 2026-08-10).
            ".id(destination)",
        ],
        "Settings/HeaderSearch.swift": [
            // The collapsed entry is a BRANCH in the body, and
            // the only thing standing between a 720 pt window
            // and a clipped control — needle through both
            // arms, since either one deleted leaves a band
            // with no search at all.
            "ifcollapsed{collapsedEntry}else{fieldEntry}",
            "privatevarcollapsed:Bool{"
                + "width.collapsesChrome&&!expanded}",
            // Opening focuses in the same act — one hop later,
            // because the field does not exist in the update
            // that opens it and a same-update focus write is
            // dropped — and ⌘K reaches the collapsed entry
            // rather than a field that is not on screen.
            "expanded=trueTask{@MainActorinfocused=true}",
            "Button(\"\",action:open)"
                + ".keyboardShortcut(\"k\",modifiers:.command)",
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
            // discovery flag — needled WITH its condition
            // (#678 Phase 4 pass 11).
            //
            // The earlier cut matched only the two calls, and
            // the condition above them was a hand-written list
            // of terminal step cases. Renaming or reordering the
            // steps would have left that list matching nothing,
            // the banner permanently dead, and this needle
            // green — it could not see the half that decides.
            // Now the seam asks the model one question, and the
            // needle reads the question.
            "ifonboardingModel.reachedEnd{"
                + "OnboardingDiscovery.markShown()"
                + "HomeFirstRunState.seed(.standard)"
                + "showMenuBarCoachMark()}"
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
