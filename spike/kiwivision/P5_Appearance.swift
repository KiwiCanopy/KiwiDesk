// P5 — can KiwiDesk switch the SYSTEM appearance (ruling 7) through
// SkyLight without a prompt? The public fallback is System Events,
// which asks for Automation once. (#2103 v0)
// ALWAYS restores the exact starting state, Auto included: atexit plus
// SIGINT/SIGTERM/SIGHUP. A crash (SIGKILL, a trap) cannot restore —
// README says how to put it back by hand.
// Flags: --system-events (use osascript instead of SkyLight),
//        --skip-same (skip the set-to-current negative).
import AppKit

// UNVERIFIED: all three names and signatures — community-reported
// SkyLight symbols, never probed on macOS 27. dlsym, nil ⇒ absent.
typealias SetLegacyFn = @convention(c) (Bool) -> Void
typealias GetLegacyFn = @convention(c) () -> Bool
// (0 light/1 dark, notify)
typealias SetNotifyingFn = @convention(c) (Int32, Bool) -> Void

struct AppearanceState: Equatable {
    var dark: Bool
    var auto: Bool
}

enum Mechanism: String { case legacy, notifying, systemEvents }

// Globals, so atexit and signal handlers (no captures) can reach them.
var p5Start: AppearanceState?
var p5Mechanism: Mechanism = .legacy
var p5Restored = false
var p5Signals: [DispatchSourceSignal] = []
var p5ThemeNotes: [UInt64] = []

let setLegacy = skyLightSymbol(
    "SLSSetAppearanceThemeLegacy",
    as: SetLegacyFn.self
)
let getLegacy = skyLightSymbol(
    "SLSGetAppearanceThemeLegacy",
    as: GetLegacyFn.self
)
let setNotifying = skyLightSymbol(
    "SLSSetAppearanceThemeNotifying",
    as: SetNotifyingFn.self
)

func readAppearance() -> AppearanceState {
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
    let style =
        CFPreferencesCopyAppValue(
            "AppleInterfaceStyle" as CFString,
            kCFPreferencesAnyApplication
        ) as? String
    let auto =
        CFPreferencesCopyAppValue(
            "AppleInterfaceStyleSwitchesAutomatically" as CFString,
            kCFPreferencesAnyApplication
        ) as? Bool ?? false
    return AppearanceState(dark: style == "Dark", auto: auto)
}

/// Asks the mechanism for `dark`. Returns an error note, nil when sent.
@discardableResult
func setDark(_ dark: Bool, via m: Mechanism) -> String? {
    switch m {
    case .legacy:
        guard let setLegacy else {
            return "SLSSetAppearanceThemeLegacy absent"
        }
        setLegacy(dark)
    case .notifying:
        guard let setNotifying else {
            return "SLSSetAppearanceThemeNotifying absent"
        }
        setNotifying(dark ? 1 : 0, true)
    case .systemEvents:
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = [
            "-e",
            "tell application \"System Events\" to tell "
                + "appearance preferences to set dark mode to \(dark)",
        ]
        let err = Pipe()
        p.standardError = err
        guard (try? p.run()) != nil else { return "osascript did not start" }
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            // -1743 = not authorized (Automation denied).
            return "osascript exit \(p.terminationStatus): "
                + String(
                    decoding: err.fileHandleForReading.readDataToEndOfFile(),
                    as: UTF8.self
                )
        }
    }
    return nil
}

/// Puts back the starting state, Auto included. Idempotent.
func p5Restore() {
    guard !p5Restored, let start = p5Start else { return }
    p5Restored = true
    if readAppearance().dark != start.dark {
        setDark(start.dark, via: p5Mechanism)
    }
    if start.auto && !readAppearance().auto {
        // UNVERIFIED: that writing the key and posting the theme
        // notification re-arms Auto the way System Settings does.
        CFPreferencesSetValue(
            "AppleInterfaceStyleSwitchesAutomatically" as CFString,
            kCFBooleanTrue,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    Thread.sleep(forTimeInterval: 1.0)
    let end = readAppearance()
    print(
        end == start
            ? "[P5] RESTORE OK — \(end)"
            : "[P5] RESTORE INCOMPLETE — started \(start), now \(end). "
                + "Put it back in "
                + "System Settings ▸ Appearance (Light/Dark/Auto) by hand."
    )
}

@main @MainActor
enum P5 {
    static func main() {
        let args = Args(probe: "P5")
        bootApp()
        // NEG: a bogus name must resolve nil, cleanly.
        let bogus = skyLightSymbol(
            "SLSSetAppearanceThemeKiwiVisionBogus",
            as: SetLegacyFn.self
        )
        verdict(
            args,
            "neg-bogus-symbol",
            bogus == nil,
            "bogus symbol resolved "
                + (bogus == nil
                    ? "nil" : "NON-NIL (the lookup is not trustworthy)")
        )
        verdict(
            args,
            "symbols",
            nil,
            "Legacy set \(setLegacy != nil), Legacy get "
                + "\(getLegacy != nil), Notifying set \(setNotifying != nil)"
        )

        p5Mechanism =
            args.has("--system-events")
            ? .systemEvents
            : setLegacy != nil ? .legacy : .notifying
        if p5Mechanism == .notifying && setNotifying == nil {
            return verdict(
                args,
                "mechanism",
                false,
                "no SkyLight setter resolved — "
                    + "re-run with --system-events for the public fallback"
            )
        }
        let start = readAppearance()
        p5Start = start
        installRestore()
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(
                "AppleInterfaceThemeChangedNotification"
            ),
            object: nil,
            queue: .main
        ) { _ in p5ThemeNotes.append(nowNS()) }
        let menuBar = CGRect(
            x: 0,
            y: 0,
            width: NSScreen.screens[0].frame.width,
            height: 24
        )
        let lumStart =
            capture(rect: menuBar).map { meanRGB($0).luminance } ?? .nan
        verdict(
            args,
            "start",
            nil,
            "\(start), mechanism \(p5Mechanism.rawValue), "
                + "legacy get \(getLegacy.map { "\($0())" } ?? "absent"), "
                + "menu bar lum \(fmt(lumStart))"
        )

        // NEG: setting the current value must change nothing.
        if !args.has("--skip-same") {
            p5ThemeNotes = []
            let note = setDark(start.dark, via: p5Mechanism)
            pump(1.0)
            let same =
                readAppearance() == start && freshWindowIsDark() == start.dark
            verdict(
                args,
                "neg-set-same",
                same,
                "state unchanged \(same), "
                    + "notifications \(p5ThemeNotes.count)"
                    + (note.map { ", " + $0 } ?? "")
            )
        }

        // The flip.
        p5ThemeNotes = []
        let want = !start.dark
        let t0 = nowNS()
        let note = setDark(want, via: p5Mechanism)
        let callMS = ms(since: t0)
        var defaultsMS: Double?
        var windowMS: Double?
        while ms(since: t0) < 2000 && (defaultsMS == nil || windowMS == nil) {
            if defaultsMS == nil, readAppearance().dark == want {
                defaultsMS = ms(since: t0)
            }
            if windowMS == nil, freshWindowIsDark() == want {
                windowMS = ms(since: t0)
            }
            pump(0.02)
        }
        let noteMS = p5ThemeNotes.first.map { Double($0 - t0) / 1e6 }
        let lumFlip =
            capture(rect: menuBar).map { meanRGB($0).luminance } ?? .nan
        let fast = (defaultsMS ?? 9e9) <= 1000 && (windowMS ?? 9e9) <= 1000
        verdict(
            args,
            "flip-within-1s",
            fast && note == nil,
            "call \(fmt(callMS)) ms; defaults "
                + "\(defaultsMS.map(fmt) ?? "never"), "
                + "fresh window \(windowMS.map(fmt) ?? "never"), notification "
                + "\(noteMS.map(fmt) ?? "none") ms; menu bar lum "
                + "\(fmt(lumStart))→"
                + "\(fmt(lumFlip)); Auto now \(readAppearance().auto)"
                + (note.map { "; " + $0 } ?? "")
        )
        verdict(
            args,
            "tcc-prompt",
            nil,
            "check the log stream and the screen — "
                + "no prompt is the pass (README)"
        )

        p5Restore()
        let end = readAppearance()
        verdict(
            args,
            "restore-exact",
            end == start,
            "start \(start), end \(end)"
        )
    }

    static func freshWindowIsDark() -> Bool {
        let w = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        w.isReleasedWhenClosed = false
        return w.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            == .darkAqua
    }

    static func installRestore() {
        atexit { p5Restore() }
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(
                signal: sig,
                queue: .main
            )
            src.setEventHandler {
                p5Restore()
                exit(128 + sig)
            }
            src.resume()
            p5Signals.append(src)
        }
    }
}
