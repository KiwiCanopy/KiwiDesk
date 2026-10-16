import AppKit
import KiwiDeskCore

/// KiwiHub's View side (#2229, #2309): which Space its Layout line
/// reads, the profiles and KiwiVision beside it, and what a pick
/// does.
extension JumpPanelController {
    func wireView(_ model: JumpModel) {
        model.loadView = { [weak self] in
            self?.viewList() ?? ViewPickList(layout: nil, items: [:])
        }
        model.onApplyView = { [weak self, weak model] pick in
            guard let self, let model else { return }
            self.apply(pick, space: model.view?.layout?.space)
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
            items: Self.items(
                layout: layout,
                profiles: (profiles.currentName, profiles.list(), broken),
                visionOn: core.kiwiVisionIsOn,
                visionChord: visionChord,
                inert: inert
            )
        )
    }

    /// Each line's items. Profile is drawn only where there is
    /// another profile to load. `inert` is why every chip greys,
    /// nil where none does.
    static func items(
        layout: LayoutPickerState?,
        profiles: (current: String?, all: [String], broken: Set<String>),
        visionOn: Bool,
        visionChord: String?,
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
        let switchable = profiles.all.contains {
            $0 != profiles.current && !profiles.broken.contains($0)
        }
        let profileItems =
            switchable
            ? profiles.all.map { name in
                ViewPickList.Item(
                    pick: .profile(name),
                    name: name,
                    isCurrent: name == profiles.current,
                    inertReason: grey,
                    refusal: profiles.broken.contains(name)
                        ? ViewPickText.profileBroken : nil
                )
            } : []
        let vision = [
            ViewPickList.Item(
                pick: .vision(false),
                name: ViewPickText.visionOff,
                isCurrent: !visionOn,
                inertReason: grey
            ),
            ViewPickList.Item(
                pick: .vision(true),
                name: ViewPickText.visionFocused,
                isCurrent: visionOn,
                inertReason: grey,
                chord: visionChord
            ),
        ]
        return [.layout: layouts, .profile: profileItems, .vision: vision]
    }

    /// Closes on a pick, then applies it — once: a click during
    /// the exit fade applies nothing. No distrust: the window the
    /// close keys again is the one the user was in.
    private func apply(_ pick: ViewPickList.Pick, space: SpaceID?) {
        guard dismiss(distrusting: false) else { return }
        switch pick {
        case .layout(let mode):
            if let space { core.applyLayout(mode, to: space) }
        case .profile(let name):
            core.loadProfileAsUser(name)
        case .vision(let on):
            core.setKiwiVision(on)
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
