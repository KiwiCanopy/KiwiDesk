import AppKit
import QuartzCore

/// The wear's frames, for the log (#3700): from ↩ to the reveal's
/// end, every gap the screen's display link saw, so a device run
/// reads how many frames the wear and the fall dropped. Main actor;
/// one line per wear, written by its owner at the close.
@MainActor
final class LookPickerFrameLog: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval?
    private var frames = 0
    private var dropped = 0
    private var longest: CFTimeInterval = 0
    private var frame: CFTimeInterval = 0
    private let started = CACurrentMediaTime()
    /// How long the wear's own call held the main thread.
    var wear: CFTimeInterval = 0

    /// Starts counting on `screen`'s display link.
    func start(on screen: NSScreen?) {
        guard let screen else { return }
        let link = screen.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        record(at: link.timestamp, frame: link.duration)
    }

    /// One frame shown at `timestamp`, `frame` seconds long: a gap
    /// of n frames counts n − 1 dropped.
    func record(at timestamp: CFTimeInterval, frame: CFTimeInterval) {
        self.frame = frame
        if let last, frame > 0 {
            let gap = timestamp - last
            longest = max(longest, gap)
            dropped += max(0, Int((gap / frame).rounded()) - 1)
        }
        last = timestamp
        frames += 1
    }

    /// Stops counting and answers the log line, nil where no frame
    /// was seen.
    func stop() -> String? {
        link?.invalidate()
        link = nil
        guard frames > 0, frame > 0 else { return nil }
        let ms = { (seconds: CFTimeInterval) in
            Int((seconds * 1000).rounded())
        }
        return "look picker wear: \(frames) frames at "
            + "\(Int((1 / frame).rounded())) Hz, \(dropped) dropped, "
            + "longest gap \(ms(longest)) ms, wear call \(ms(wear)) ms, "
            + "\(ms(CACurrentMediaTime() - started)) ms in all"
    }
}
