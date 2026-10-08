import AppKit
import Foundation

@testable import KiwiDeskCore

/// One of AeroSpace's recorded AX dumps (#1883), read through an
/// allowlist so nothing but a recorded FACT reaches detection.
struct AXDump {
    /// Every key the corpus reads. The `Aero.*` keys here are
    /// facts AeroSpace recorded — the app's identity and policy,
    /// the window's CGWindow layer, the reads that failed — and
    /// never one of its classifications.
    static let readKeys: Set<String> = [
        "AXRole", "AXSubrole", "AXTitle", "AXChildren",
        "AXCloseButton", "AXMinimizeButton", "AXZoomButton",
        "AXFullScreenButton", "Aero.App.appBundleId",
        "Aero.App.nsApp.activationPolicy", "Aero.windowLevel",
        "Aero.AxFailed",
    ]
    static let buttonKeys = [
        "AXCloseButton", "AXMinimizeButton", "AXZoomButton",
        "AXFullScreenButton",
    ]
    /// A pid that is never the test process, so no dump reads as
    /// one of KiwiDesk's own windows.
    static let foreignPID: pid_t = 1

    /// The path below `AXDumps/`, without the extension.
    let name: String
    /// The dump, cut to `readKeys`.
    let values: [String: Any]

    init(name: String, data: Data) throws {
        let object = try JSONSerialization.jsonObject(
            with: data,
            options: [.json5Allowed]
        )
        self.name = name
        values = (object as? [String: Any] ?? [:])
            .filter { Self.readKeys.contains($0.key) }
    }

    /// A recorded string; `.some(nil)` where the dump recorded no
    /// value, nil where it recorded nothing at all.
    private func recorded(_ key: String) -> String?? {
        guard let value = values[key] else { return nil }
        return .some(value as? String)
    }

    var role: String? { recorded("AXRole").map { $0 ?? "" } }
    var subrole: String? { recorded("AXSubrole").map { $0 ?? "" } }
    var title: String { recorded("AXTitle").flatMap { $0 } ?? "" }
    var bundleID: String?? { recorded("Aero.App.appBundleId") }

    /// The CGWindow layer, which AeroSpace records under its own
    /// names for 0 and 3; nil where the dump has none.
    var layer: Int? {
        if let level = values["Aero.windowLevel"] as? Int {
            return level
        }
        switch values["Aero.windowLevel"] as? String {
        case "normalWindow": return 0
        case "alwaysOnTopWindow": return 3
        default: return nil
        }
    }

    var policy: NSApplication.ActivationPolicy? {
        switch values["Aero.App.nsApp.activationPolicy"] as? String {
        case "regular": .regular
        case "accessory": .accessory
        case "prohibited": .prohibited
        default: nil
        }
    }

    /// The title-bar button reading `AXHelper.windowTraits` makes:
    /// true for any present, nil where a read failed or the dump
    /// lacks the key, false where every one answered none.
    var hasTitlebarButton: Bool? {
        let failed = (values["Aero.AxFailed"] as? String) ?? ""
        let buttons: [Bool?] = Self.buttonKeys.map { key in
            switch values[key] {
            case nil: nil
            case is [String: Any]: true
            default: failed.contains("get.\(key)") ? nil : false
            }
        }
        return WindowTraits.titlebarButton(from: buttons)
    }

    /// AeroSpace skips `AXChildren`, so this is nil throughout
    /// the pinned corpus.
    var childCount: Int? { (values["AXChildren"] as? [Any])?.count }
}

/// Whether admission keeps a window or ignores it outright.
enum DumpAdmission: Equatable {
    case kept
    case ignored
}

/// What KiwiDesk's rules decide of one dump. A nil field is a rule
/// that reads a fact the dump lacks: "not decidable from the
/// dump", never a guess.
struct DumpVerdict: Equatable {
    /// `autoFloatVerdict`'s answer, which `tileRefusal` reads.
    var detection: FloatVerdict?
    /// The ignore gate (`FloatDetection.shouldIgnore`).
    var admission: DumpAdmission?
    /// The shadow rule's reading of the window alone (#1785).
    var shell: ShellReading?
}

extension AXDump {
    /// The dump through the production rules, with the config's
    /// rules empty: the classifier's own behaviour.
    var verdict: DumpVerdict {
        DumpVerdict(
            detection: detection,
            admission: admission,
            shell: shell
        )
    }

    private var isAccessory: Bool? {
        policy.map {
            EventLoop.classifiesAsOverlay(
                pid: Self.foreignPID,
                activationPolicy: $0
            )
        }
    }

    private var detection: FloatVerdict? {
        guard let role, let subrole, let layer, let policy,
            let bundleID
        else { return nil }
        let title = title
        return EventLoop.composeVerdict(
            .facts(
                WindowFacts(role: role, subrole: subrole, layer: layer) {
                    title
                }
            ),
            pid: Self.foreignPID,
            activationPolicy: policy,
            tilesAsOwnWindow: false,
            bundleID: bundleID,
            rules: FloatRules()
        )
    }

    private var admission: DumpAdmission? {
        guard role != nil, let layer, let isAccessory, let bundleID
        else { return nil }
        let ignored = FloatDetection.shouldIgnore(
            bundleID: bundleID,
            layer: layer,
            isAccessory: isAccessory,
            rules: IgnoreRules()
        )
        return ignored ? .ignored : .kept
    }

    /// Decidable only where the window is furnished or its
    /// children were recorded: a shell's verdict needs the
    /// children the dump skipped, and its siblings.
    private var shell: ShellReading? {
        let button = hasTitlebarButton
        guard role != nil, button == true || childCount != nil
        else { return nil }
        return ShellReading.of(button: button, children: childCount)
    }
}
