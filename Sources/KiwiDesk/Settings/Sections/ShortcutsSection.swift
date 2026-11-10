import KiwiDeskCore
import SwiftUI

/// Shortcuts settings section, rendered FROM the census (#68,
/// #678): the census owns placement, `ShortcutsRowOrder` display
/// order, `ShortcutsFamilyRows` the family→rows expansion —
/// `ShortcutsCensusRenderTests` pins all three. The Inactive
/// shortcuts card is deliberately NOT censused: its rows are
/// instances of families already placed, so the card is
/// hand-mounted and the guard states why it holds no keys.
/// Single active recorder (#33), duplicate blocking (#34), live
/// conflict detection (#35).
struct ShortcutsSection: View {
    @Environment(\.accessibilityReduceMotion)
    var reduceMotion
    @ObservedObject var model: SettingsModel
    @State var advancedExpanded = false
    /// Armed by the user's own click on Mouse & Trackpad, once per
    /// visit, and spent by the part's first picture (owner ruling
    /// 2026-09-29, carried to the segment by #3184).
    @State var gesturesPlay = false
    @State var gesturesPlayed = false
    /// `@State`, never an observed object: the body must not
    /// subscribe to the reading only the bar draws (#1520).
    @State var jumpTracker = ShortcutsJumpTracker()
    /// Bumped by Add binding, whose row lands at the page's end.
    @State var luaAdded = 0
    /// Set once a scroll targets a row no part is known to hold —
    /// the recorder's, or a reveal's through `nav` — and the page then
    /// builds every part, as before #3060.
    @State var buildsWholePage = false
    @State private var endScroll: Task<Void, Never>?
    @State var targetScroll: Task<Void, Never>?
    @StateObject var coordinator =
        RecorderCoordinator(scrollsInPlace: true)

    /// The selected layer lives on `nav` rather than here
    /// (#1127): the live preview panel is this section's
    /// sibling, so it can only learn the layer from the model.
    /// Cleared per visit by `SettingsNavigation.resetSurfaces()`.
    var selection: Binding<String> {
        Binding(
            get: { selected },
            set: { model.nav.shortcutsLayer = $0 }
        )
    }

    var selected: String {
        model.nav.shortcutsLayerSelection
    }

    /// The part shown (#3184), on `nav` like the layer.
    var segment: ShortcutsSegment {
        model.nav.shortcutsSegmentSelection
    }

    var body: some View {
        // Once per pass: every group reads it (#3060).
        let expander = self.expander
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                segmentControl(proxy)
                if segment == .builtIn {
                    jumpBar(proxy, expander: expander)
                }
                page(expander)
            }
            // A container, so the pane's title names it rather
            // than renaming every chip beneath (#812).
            .accessibilityElement(children: .contain)
            .onChange(of: coordinator.scrollTarget) {
                _,
                target in
                guard let target else { return }
                coordinator.scrollTarget = nil
                scroll(to: target, proxy: proxy, expander: expander)
            }
            .onChange(of: luaAdded) { _, _ in
                scrollToEnd(proxy)
            }
        }
        .onAppear {
            ensureSelection()
            // Suspend hotkeys while capturing to avoid trigger during edit
            // (#213).
            coordinator.onArmedChange = { [model] armed in
                model.setRecorderArmed(armed)
            }
            coordinator.segmentHolding = { [model] anchor in
                model.shortcutsSegment(holding: anchor)
            }
            takeWholePageRequest()
        }
        // Here rather than on the drawer, which the lazy stack builds
        // only when it is scrolled to (#3060).
        .onAppear {
            let gates = ShortcutsGates(config: model.config)
            if gates.luaBindingsExist(in: selected) {
                advancedExpanded = true
            }
        }
        .onChange(of: model.nav.shortcutsWholePage) { _, _ in
            takeWholePageRequest()
        }
        .onDisappear { model.shortcutsPage.built = [] }
        .onChange(of: model.config.layers.map(\.name)) {
            _,
            _ in
            ensureSelection()
        }
        .onChange(of: model.target) { _, _ in
            ensureSelection()
            coordinator.invalidate()
        }
        .onChange(of: selected) { _, _ in
            coordinator.invalidate()
        }
    }

    /// The page's bottom edge, padding included.
    static let pageEnd = "shortcuts.page_end"
    /// The page's top edge: always laid out, unlike a part that may
    /// draw nothing, so a segment pick can open there (#3184).
    static let pageTop = "shortcuts.page_top"

    /// Scrolls to the page's end, then again un-animated once the
    /// appended row is laid out — a yield does not promise layout
    /// (`SettingsView.reveal`).
    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        endScroll?.cancel()
        endScroll = Task { @MainActor in
            await Task.yield()
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: SettingsReveal.scroll)
            ) { proxy.scrollTo(Self.pageEnd, anchor: .bottom) }
            try? await Task.sleep(
                nanoseconds: SettingsReveal.nanoseconds(
                    SettingsReveal.scroll + SettingsReveal.settle
                )
            )
            guard !Task.isCancelled else { return }
            proxy.scrollTo(Self.pageEnd, anchor: .bottom)
        }
    }

    private var layerIndex: Int {
        model.config.layers.firstIndex {
            $0.name == selected
        } ?? 0
    }

    var bindingsBinding: Binding<[KeyBinding]> {
        Binding(
            get: { model.config.layers[layerIndex].bindings },
            set: {
                model.config.layers[layerIndex].bindings = $0
            }
        )
    }

    /// One lazily built child per `ShortcutsPagePart` of the part
    /// shown, so a visit builds the parts on screen rather than
    /// every row (#3060, #3184). Rows appear as a list's rows do,
    /// with no motion of their own (owner ruling on #3060).
    func page(_ expander: ShortcutsFamilyRows) -> some View {
        let segment = self.segment
        return ScrollView {
            stack {
                ForEach(ShortcutsPagePart.parts(in: segment)) { part in
                    // `ShortcutsPageState` states the set's contract.
                    ruled(part, in: segment) {
                        self.part(part, expander: expander)
                    }
                    .onAppear {
                        model.shortcutsPage.built.insert(part)
                    }
                    .onDisappear {
                        model.shortcutsPage.built.remove(part)
                    }
                }
            }
            .padding(.horizontal, SettingsMetrics.paneInset)
            .settingsPageBottom()
            .overlay(alignment: .bottom) {
                Color.clear.frame(height: 1).id(Self.pageEnd)
            }
            .overlay(alignment: .top) {
                Color.clear.frame(height: 1).id(Self.pageTop)
            }
            .shortcutsJumpSlot(.content)
            .environment(\.keybindingLayerName, selected)
            .environment(\.shortcutsSegment, segment)
            // One live read per section render (#1105), so
            // every row narrates the same verdict (#1126).
            .environment(
                \.disabledSystemShortcuts,
                model.disabledSystemShortcuts()
            )
            .recorderKeys(model)
            .environmentObject(coordinator)
        }
        .shortcutsJumpSlot(.viewport)
        // The chips' groups report under their anchor ids.
        .mapsSectionFrames()
        .onPreferenceChange(ShortcutsJumpFrames.self) { frames in
            jumpTracker.slots(frames)
        }
        .onPreferenceChange(SettingsSectionFrames.self) { frames in
            jumpTracker.sections(frames)
        }
    }

    /// The part, under the page's rule where `ruledAbove(in:)` asks
    /// for one.
    @ViewBuilder private func ruled(
        _ part: ShortcutsPagePart,
        in segment: ShortcutsSegment,
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        if part.ruledAbove(in: segment) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsTheme.hairlineSubtle
                    .frame(height: 1)
                    .accessibilityHidden(true)
                content()
            }
        } else {
            content()
        }
    }

    /// Lazy, until a scroll needs a row no part is known to hold.
    @ViewBuilder private func stack(
        @ViewBuilder _ content: () -> some View
    ) -> some View {
        if buildsWholePage {
            VStack(alignment: .leading, spacing: 16, content: content)
        } else {
            LazyVStack(alignment: .leading, spacing: 16, content: content)
        }
    }

    @ViewBuilder private func part(
        _ part: ShortcutsPagePart,
        expander: ShortcutsFamilyRows
    ) -> some View {
        switch part {
        case .conflictBanner:
            KeybindingConflictBanner(model: model)
        // Above the layer header, set off by the page's rule, so
        // nothing in it reads as per-layer (#1726, #1520; amending
        // the 2026-08-04 ruling that the layers card leads).
        case .modifierKeys:
            ModifierKeysCard(model: model)
        case .gestures:
            GesturesPart(model: model, playArmed: $gesturesPlay)
        case .layers:
            LayersCard(
                model: model,
                bindings: bindingsBinding,
                selected: selection,
                expander: expander
            )
        case .keySequences:
            KeySequencesCard(
                model: model,
                bindings: bindingsBinding,
                expander: expander
            )
        case .defaultShortcuts:
            DefaultShortcutsRow(model: model, selected: selection)
        case .showHide, .focus, .moveWindows, .macosDesktops, .layout,
            .sizeFloat, .pocket, .openApplications:
            actionGroup(part, expander: expander)
        case .inactive:
            // Orphaned space-targeting rows (#92).
            OrphanedShortcutsGroup(
                model: model,
                bindings: bindingsBinding,
                spaces: expander.liveSpaces,
                layers: model.config.layers.map(\.name)
            )
        case .luaBindings:
            luaDrawer
        }
    }

    /// Shut until a layer carries a Lua binding, then open on
    /// arrival — never swapped for an open card (#1125, #2654).
    private var luaDrawer: some View {
        SettingsDisclosure(
            SettingsCatalog.shortcuts.luaBindings,
            chrome: .card,
            isExpanded: $advancedExpanded
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(advancedDrawerCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ActionsListLink()
                AdvancedLuaGroup(
                    model: model,
                    bindings: bindingsBinding,
                    onAdd: { luaAdded += 1 }
                )
            }
            .padding(.top, 8)
        }
    }
}
