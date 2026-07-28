import KiwiDeskCore

/// One searchable, revealable thing in the Settings GUI (#277):
/// its localized label, the local surface that must be selected
/// for it to be on screen, and a **stable anchor id** that is
/// independent of the label text.
///
/// Declared once, in `SettingsCatalog`, and read by BOTH the
/// render site (which takes the descriptor and shows
/// `control.text`) and the search index (which enumerates the
/// catalog by reflection) — one list, and it is the render path,
/// so there is no hand-mirrored index to drift from the views
/// (`.claude/rules/parity-tests.md`).
///
/// Identity is `id`, never the text. Part 1 anchored by resolved
/// label text, which is measured-dead one level down: Appearance
/// renders "Color" six times simultaneously, and
/// `SlotSizeRows.sizeLabel` swaps with a sibling picker — text
/// `.id()` churn would tear down rows holding uncommitted
/// `@State` drafts and keyboard focus mid-edit. The id is the
/// `L()` key, prefixed by an `instance` tag when one declaration
/// per co-mounted view is needed (`LayoutAppBarGroup` renders
/// twice, so each mount takes its own descriptor and `scrollTo`
/// stays well-defined).
struct SettingsControl: Hashable, Sendable {
    private enum Label: Hashable, Sendable {
        case tuple(key: String, english: String)
        case mode(LayoutMode)
    }

    private let label: Label
    /// The local branch that must be showing before this
    /// control exists in the view tree at all.
    var surface: SettingsSurface = .main
    private let instanceTag: String?

    /// The one tuple-literal shape `scripts/extract-keys` scans
    /// (beside `L(...)` and `SettingsDrawer(...)`): key and
    /// English must be adjacent string literals.
    init(
        _ key: String,
        _ english: String,
        surface: SettingsSurface = .main,
        instance: String? = nil
    ) {
        self.label = .tuple(key: key, english: english)
        self.surface = surface
        self.instanceTag = instance
    }

    /// A Layout Defaults mode tab. Text routes through
    /// `LayoutMode.displayName`, so the mode-name tuples keep
    /// their one home in `LayoutModeGlyph.swift`.
    static func layoutMode(_ mode: LayoutMode) -> SettingsControl {
        SettingsControl(mode: mode)
    }

    private init(mode: LayoutMode) {
        self.label = .mode(mode)
        self.surface = .layoutMode(mode)
        self.instanceTag = nil
    }

    /// The scroll-anchor id — what the reveal
    /// modifiers tag and what `SettingsAnchor.anchor` carries.
    var id: String {
        switch label {
        case .tuple(let key, _):
            guard let instanceTag else { return key }
            return "\(instanceTag)/\(key)"
        case .mode(let mode):
            return "layout_mode/\(mode.rawValue)"
        }
    }

    /// The `L()` key, or nil for a mode tab. For the guards.
    var key: String? {
        switch label {
        case .tuple(let key, _): return key
        case .mode: return nil
        }
    }

    /// The resolved, localized label the user sees.
    @MainActor var text: String {
        switch label {
        case .tuple(let key, let english):
            return L(key, english)
        case .mode(let mode):
            return mode.displayName
        }
    }
}

/// A disclosure drawer's label control plus its interior
/// controls, declared as one nested value so the
/// control→parent-drawer relation has exactly one home: the
/// render site mounts this value (`SettingsDisclosure`), and the
/// index recurses into it — never a hand-maintained parent
/// column, whose drift mode is "add a row, forget the parent,
/// reveal scrolls into a subtree that was never built".
struct SettingsDrawer<Children> {
    let control: SettingsControl
    let children: Children

    init(
        _ key: String,
        _ english: String,
        surface: SettingsSurface = .main,
        instance: String? = nil,
        children: Children
    ) {
        self.control = SettingsControl(
            key,
            english,
            surface: surface,
            instance: instance
        )
        self.children = children
    }
}

extension SettingsDrawer: Sendable where Children: Sendable {}

/// A drawer whose interior is not cataloged yet (#277 fills
/// iteratively).
struct SettingsNoChildren: Sendable {}

extension SettingsDrawer where Children == SettingsNoChildren {
    init(
        _ key: String,
        _ english: String,
        surface: SettingsSurface = .main,
        instance: String? = nil
    ) {
        self.init(
            key,
            english,
            surface: surface,
            instance: instance,
            children: SettingsNoChildren()
        )
    }
}

/// Type-erased view of a drawer for the reflection enumerator
/// and the `SettingsDisclosure` auto-expand decision.
protocol AnySettingsDrawer {
    var control: SettingsControl { get }
    var childContainer: Any { get }
}

extension SettingsDrawer: AnySettingsDrawer {
    var childContainer: Any { children }
}

extension AnySettingsDrawer {
    /// Ids of every control inside the drawer, at any depth.
    var childIDs: Set<String> {
        Set(
            SettingsControlIndex.entries(in: childContainer)
                .map { $0.control.id }
        )
    }

    /// Whether revealing `target` requires this drawer open.
    ///
    /// True only for an *interior* control. A direct hit on the
    /// drawer's own label deliberately does not expand it — the
    /// header is visible and highlighted, and opening it is one
    /// honest click (part-1 design call, do not relitigate).
    func shouldExpand(revealing target: String?) -> Bool {
        guard let target else { return false }
        return childIDs.contains(target)
    }
}

/// One enumerated control: the descriptor, the drawer label
/// above it (nil at top level), and the catalog property path
/// that declared it — the token the source-scanning guards look
/// for at render sites.
struct SettingsIndexEntry {
    let control: SettingsControl
    let parent: SettingsControl?
    let propertyPath: [String]
}

/// Reflection over the catalog's declarations: every stored
/// `SettingsControl` and every `SettingsDrawer` (label first,
/// then its children, depth-first, in declaration order). Adding
/// a declaration is indexing it — there is no second list to
/// forget.
enum SettingsControlIndex {
    static func entries(in container: Any) -> [SettingsIndexEntry] {
        var out: [SettingsIndexEntry] = []
        for child in Mirror(reflecting: container).children {
            let name = child.label ?? ""
            if let control = child.value as? SettingsControl {
                out.append(
                    SettingsIndexEntry(
                        control: control,
                        parent: nil,
                        propertyPath: [name]
                    )
                )
            } else if let drawer = child.value as? AnySettingsDrawer {
                out.append(
                    SettingsIndexEntry(
                        control: drawer.control,
                        parent: nil,
                        propertyPath: [name]
                    )
                )
                for sub in entries(in: drawer.childContainer) {
                    out.append(
                        SettingsIndexEntry(
                            control: sub.control,
                            parent: drawer.control,
                            propertyPath: [name] + sub.propertyPath
                        )
                    )
                }
            }
        }
        return out
    }

    /// Property paths of stored members `entries(in:)` did NOT
    /// enumerate — anything that is neither a `SettingsControl`
    /// nor a `SettingsDrawer`, at any depth. Always empty for a
    /// well-formed catalog; the catalog guard fails loudly when it
    /// is not, so a member shape the enumerator silently drops (a
    /// `[SettingsControl]` collection, a stray helper) becomes a
    /// test failure instead of a rendered-but-unsearchable hole —
    /// the exact silent-gap class the one-list design exists to
    /// close. (A *computed* `var` is invisible to `Mirror` and so
    /// to this walk too; a source scan guards that separately.)
    static func unenumerated(in container: Any) -> [String] {
        var out: [String] = []
        for child in Mirror(reflecting: container).children {
            let name = child.label ?? "<unnamed>"
            if child.value is SettingsControl { continue }
            if let drawer = child.value as? AnySettingsDrawer {
                out += unenumerated(in: drawer.childContainer)
                    .map { "\(name).\($0)" }
            } else {
                out.append(name)
            }
        }
        return out
    }
}
