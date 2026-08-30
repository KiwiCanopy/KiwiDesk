import KiwiDeskCore

/// Descriptor for searchable, revealable settings control with stable anchor
/// ID (#277).
struct SettingsControl: Hashable, Sendable {
    private enum Label: Hashable, Sendable {
        case tuple(key: String, english: String)
        case mode(LayoutMode)
    }

    private let label: Label
    /// Surface that must be active for this control to appear in view
    /// hierarchy.
    var surface: SettingsSurface = .main
    private let instanceTag: String?

    /// Tuple literal shape scanned by `scripts/extract-keys`.
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

    /// Layout Defaults mode tab descriptor.
    static func layoutMode(_ mode: LayoutMode) -> SettingsControl {
        SettingsControl(mode: mode)
    }

    private init(mode: LayoutMode) {
        self.label = .mode(mode)
        self.surface = .layoutMode(mode)
        self.instanceTag = nil
    }

    /// Scroll-anchor identifier for search reveal navigation.
    var id: String {
        switch label {
        case .tuple(let key, _):
            guard let instanceTag else { return key }
            return "\(instanceTag)/\(key)"
        case .mode(let mode):
            return "layout_mode/\(mode.rawValue)"
        }
    }

    /// Localization key or nil for layout mode tabs.
    var key: String? {
        switch label {
        case .tuple(let key, _): return key
        case .mode: return nil
        }
    }

    /// Resolved localized label string.
    @MainActor var text: String {
        switch label {
        case .tuple(let key, let english):
            return L(key, english)
        case .mode(let mode):
            return mode.displayName
        }
    }
}

/// Nested settings disclosure drawer descriptor linking label control to
/// children (#277).
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

/// Placeholder for drawers without cataloged children (#277).
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

/// Type-erased drawer interface for reflection and auto-expansion.
protocol AnySettingsDrawer {
    var control: SettingsControl { get }
    var childContainer: Any { get }
}

extension SettingsDrawer: AnySettingsDrawer {
    var childContainer: Any { children }
}

extension AnySettingsDrawer {
    /// Control IDs of all descendants within this drawer.
    var childIDs: Set<String> {
        Set(
            SettingsControlIndex.entries(in: childContainer)
                .map { $0.control.id }
        )
    }

    /// Whether drawer must expand to reveal target control ID.
    func shouldExpand(revealing target: String?) -> Bool {
        guard let target else { return false }
        return childIDs.contains(target)
    }
}

/// Catalog entry metadata emitted by reflection walker (`parity-tests.md`).
struct SettingsIndexEntry {
    let control: SettingsControl
    let parent: SettingsControl?
    let propertyPath: [String]
}

/// Reflection walker over `SettingsCatalog` declarations.
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

    /// Identifies stored members that failed catalog enumeration.
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
