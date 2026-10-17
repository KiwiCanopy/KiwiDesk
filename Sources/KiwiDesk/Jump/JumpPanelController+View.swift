import AppKit
import KiwiDeskCore

/// KiwiHub's View side (#2229, #2309): which Space its Layout line
/// reads, the profiles and KiwiVision beside it, and what a pick
/// does.
extension JumpPanelController {
    func wireView(_ model: JumpModel) {
        model.loadView = { [weak self] in
            self?.viewList()
                ?? ViewPickList(layout: nil, kiwiVisionOn: false, items: [:])
        }
        model.onApplyView = { [weak self, weak model] pick in
            guard let self, let model else { return }
            self.apply(pick, space: model.view?.layout?.space)
        }
        model.newProfileName = { [weak self] typed in
            self?.core.profiles.newProfileName(typed: typed)
        }
        // Saves the LIVE arrangement — `save_profile`, never
        // Settings' draft commit — and claims the connected screen
        // setup as every save does (#2359 ruling 3). No load: the
        // saved profile is the live one.
        // A save that does not land keeps the panel open, saying so.
        model.onSaveProfile = { [weak self] name in
            guard let self, self.core.saveProfileAsUser(name) else {
                return false
            }
            _ = self.dismiss(distrusting: false)
            return true
        }
        model.onKeep = { [weak self, weak model] in
            self?.core.barMenuHooks.keepLayout()
            model?.reloadView()
        }
        // No distrust: a close arms none, and the next own report
        // is Settings coming forward (#952).
        model.onViewSettings = { [weak self, weak model] line, item in
            // No Space: Layout Defaults opens on its first tab.
            let live = model?.view?.layout?.live ?? LayoutMode.allCases[0]
            guard let self, self.dismiss(distrusting: false) else { return }
            self.core.barMenuHooks.openSettings(
                Self.landing(line, item?.pick, live: live)
            )
        }
    }

    /// Re-reads a shown View side: KiwiVision or its lenses
    /// changed through another door — a chord, a verb.
    func reloadViewIfShown() {
        guard isOpen, let model = currentModel, model.scope == .view
        else { return }
        model.reloadView()
    }

    /// The lines as Core reads now. Every chip greys while
    /// KiwiDesk boots or waits for Start Tiling (#2309 ruling 9).
    func viewList() -> ViewPickList {
        let inert =
            core.bootPhase.isStarting
            ? ViewPickText.starting
            : ViewPickText.held(hold())
        let layout = pickerSpace.flatMap(core.layoutPickerState(for:))
        let profiles = core.profiles
        let broken = Set(profiles.brokenProfiles().map(\.name))
        let visionChord = ShortcutsOpenBinding.comboGlyphs(
            core: core,
            lua: KeybindingCatalog.toggleKiwiVision.lua
        )
        return ViewPickList(
            layout: layout,
            kiwiVisionOn: core.kiwiVisionActive != .off,
            items: Self.items(
                layout: layout,
                profiles: (profiles.currentName, profiles.list(), broken),
                vision: (core.kiwiVisionActive, core.kiwiVisionLensChoices),
                visionChord: visionChord,
                lensChord: { [core] in
                    ShortcutsOpenBinding.lensGlyphs(core: core, lens: $0)
                },
                offersNewLens: core.isGuiManaged,
                inert: inert
            )
        )
    }

    /// Each line's items. The Profile line always shows, ending in
    /// Save as New Profile… (#2359 ruling 3, amending #2309 ruling
    /// 2). `inert` is why every chip greys, nil where none does.
    static func items(
        layout: LayoutPickerState?,
        profiles: (current: String?, all: [String], broken: Set<String>),
        vision: (active: VisionActive, lenses: [VisionLensChoice]),
        visionChord: String?,
        lensChord: (String) -> String?,
        offersNewLens: Bool,
        inert: String?
    ) -> [ViewPickList.Line: [ViewPickList.Item]] {
        let grey = inert
        let layouts = LayoutMode.allCases.map { mode in
            ViewPickList.Item(
                pick: .layout(mode),
                name: mode.displayName,
                spellings: [mode.rawValue],
                isCurrent: mode == layout?.live,
                inertReason: grey
                    ?? (layout == nil ? ViewPickText.noSpace : nil)
            )
        }
        let profileItems =
            profiles.all.map { name in
                ViewPickList.Item(
                    pick: .profile(name),
                    name: name,
                    isCurrent: name == profiles.current,
                    inertReason: grey,
                    refusal: profiles.broken.contains(name)
                        ? ViewPickText.profileBroken : nil
                )
            } + [
                // Saving the live arrangement is a machine act, so
                // it greys while KiwiDesk boots.
                ViewPickList.Item(
                    pick: .newProfile,
                    name: ViewPickText.newProfile,
                    inertReason: grey
                )
            ]
        return [
            .layout: layouts, .profile: profileItems,
            .vision: visionItems(
                vision,
                chord: visionChord,
                lensChord: lensChord,
                offersNewLens: offersNewLens,
                inert: grey
            ),
        ]
    }

    /// Default, each lens, then New Lens… (#2103 rulings 55–57); no
    /// Off chip, the current chip turning KiwiVision off. A lens
    /// Core refuses greys with its reason; the lens on is never
    /// refused, since `followActiveLens` turns a refused one off.
    private static func visionItems(
        _ vision: (active: VisionActive, lenses: [VisionLensChoice]),
        chord: String?,
        lensChord: (String) -> String?,
        offersNewLens: Bool,
        inert: String?
    ) -> [ViewPickList.Item] {
        let plain = ViewPickList.Item(
            pick: .vision(lens: nil),
            name: ViewPickText.visionDefault,
            isCurrent: vision.active == .plain,
            inertReason: inert,
            chord: chord
        )
        let lenses = vision.lenses.map { lens in
            ViewPickList.Item(
                pick: .vision(lens: lens.name),
                name: lens.name,
                isCurrent: vision.active == .lens(lens.name),
                inertReason: inert,
                refusal: lens.refusal.map(ViewPickText.lensRefusal),
                chord: lensChord(lens.name)
            )
        }
        // Opening Settings is no machine act, so no boot grey; a
        // Lua-owned setup greys it, its reason short enough for a chip.
        let create = ViewPickList.Item(
            pick: .newLens,
            name: ViewPickText.newLens,
            refusal: offersNewLens
                ? nil : ViewPickText.newLensLuaOwned
        )
        return [plain] + lenses + [create]
    }

    /// Closes on a pick, then applies it — once: a click during
    /// the exit fade applies nothing. No distrust: the window the
    /// close keys again is the one the user was in.
    private func apply(_ pick: ViewPickList.Pick, space: SpaceID?) {
        guard dismiss(distrusting: false) else { return }
        switch pick {
        case .newProfile:
            // `JumpModel.applyView` names it in the panel instead.
            break
        case .layout(let mode):
            if let space { core.applyLayout(mode, to: space) }
        case .profile(let name):
            core.loadProfileAsUser(name)
        case .visionOff:
            core.setKiwiVision(.off)
        case .vision(lens: nil):
            core.setKiwiVision(.plain)
        case .vision(lens: let name?):
            core.setKiwiVision(.lens(name))
        case .newLens:
            core.barMenuHooks.openSettings(.newLens)
        }
    }

    static func landing(
        _ line: ViewPickList.Line,
        _ pick: ViewPickList.Pick?,
        live: LayoutMode
    ) -> SettingsLanding {
        switch line {
        case .layout:
            if case .layout(let mode) = pick {
                return .layoutDefaults(mode)
            }
            return .layoutDefaults(live)
        case .profile: return .profiles
        case .vision: return .kiwiVision
        }
    }
}
