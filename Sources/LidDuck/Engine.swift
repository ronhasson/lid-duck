import Foundation

// All engine calls are serialized by the app's main-thread timer.
struct VolumeState: Equatable {
    let device: UInt32
    let channels: [UInt32]
    let values: [Float]
    var muted: Bool? = nil
    func matches(_ other: Self, tolerance: Float = 0.002) -> Bool {
        muted == other.muted && device == other.device && channels == other.channels && values.count == other.values.count && zip(values, other.values).allSatisfy { abs($0 - $1) < tolerance }
    }
}
protocol VolumeIO: AnyObject {
    func read() throws -> VolumeState
    func write(_ state: VolumeState) throws
}
final class DuckEngine {
    let audio: VolumeIO
    var trigger = 70.0
    var restore = 85.0
    var duck: Float = 0.15
    var duration = 0.2
    var enabled = true
    private(set) var status = "Ready"
    private(set) var ducked = false
    private var overridden = false
    private var candidate: Double?
    private var candidateClosing: Bool?
    // The baseline survives the entire duck/restore cycle, including reversals.
    private var saved: VolumeState?
    private var expected: VolumeState?
    private var expectedTolerance: Float = 0.002
    private var ramp: (start: VolumeState, end: VolumeState, time: Double)?
    private var recovering = false
    private var restorationRequested = false
    init(audio: VolumeIO) { self.audio = audio }

    private func validateOwnership(_ current: VolumeState) {
        if let expected, !expected.matches(current, tolerance: expectedTolerance) {
            saved = nil; ramp = nil; self.expected = nil
            if ducked { overridden = true }
        }
    }
    func tick(angle: Double?, now: Double) {
        do {
            let current = try audio.read()
            validateOwnership(current)
            if restorationRequested {
                try restoreImmediately(current: current)
                status = enabled ? "Ready" : "Disabled"
                return
            }
            if recovering {
                // Resume from the validated actual value instead of jumping to a
                // fade position whose clock advanced while audio was unavailable.
                if let ramp { self.ramp = (current, ramp.end, now) }
                recovering = false
            }
            if !enabled || angle == nil {
                candidate = nil; candidateClosing = nil
                release(current: current, now: now)
                try advance(now: now)
                status = enabled ? "Lid sensor unavailable" : "Disabled"
                return
            }
            try advance(now: now)
            status = overridden ? "Manual override — reopen lid to rearm" : (ducked ? "Ducked" : "Ready")
            let closing = !ducked && angle! < trigger
            let opening = ducked && angle! > restore
            if closing || opening {
                if candidateClosing != closing { candidate = now; candidateClosing = closing }
                if let candidate, now - candidate >= 0.25 {
                    self.candidate = nil; candidateClosing = nil
                    let actual = try audio.read()
                    validateOwnership(actual)
                    if closing {
                        // An interrupted restoration still owns the original baseline.
                        if saved == nil { saved = actual }
                        expected = actual; expectedTolerance = 0.002
                        ducked = true; overridden = false
                        let peak = actual.values.max() ?? 0
                        let scale: Float = peak > 0 ? min(1, duck / peak) : 1
                        let target = VolumeState(device: actual.device, channels: actual.channels, values: actual.values.map { $0 * scale }, muted: actual.muted)
                        ramp = (actual, target, now); status = "Ducked"
                    } else {
                        release(current: actual, now: now)
                        status = "Ready"
                    }
                }
            } else { candidate = nil; candidateClosing = nil }
        } catch {
            // A failed read is uncertainty, not evidence that ownership changed.
            // Keep the baseline and last owned value; validate both on recovery.
            recovering = true
            candidate = nil; candidateClosing = nil
            status = "Audio unavailable: \(error.localizedDescription)"
        }
    }
    private func release(current: VolumeState, now: Double) {
        guard ducked else { return }
        ducked = false
        if !overridden, let saved, let expected, expected.matches(current, tolerance: expectedTolerance) {
            ramp = (current, saved, now)
        } else { ramp = nil; expected = nil; saved = nil }
        overridden = false
    }
    private func advance(now: Double) throws {
        guard let ramp else { return }
        let fraction = Float(duration <= 0 ? 1 : min(1, max(0, (now - ramp.time) / duration)))
        let next = VolumeState(device: ramp.end.device, channels: ramp.end.channels, values: zip(ramp.start.values, ramp.end.values).map { $0 + ($1 - $0) * fraction }, muted: ramp.end.muted)
        // Recheck ownership immediately before writing, including during a fade.
        let before = try audio.read()
        validateOwnership(before)
        guard self.ramp != nil else { return }
        try audio.write(next)
        // If readback temporarily fails after a successful write, remember what
        // was written and allow driver quantization when validating recovery.
        expected = next; expectedTolerance = 0.02
        let actual = try audio.read()
        guard next.matches(actual, tolerance: 0.02) else {
            validateOwnership(actual)
            throw AudioFailure(message: "Output changed during transition")
        }
        expected = actual; expectedTolerance = 0.002
        if fraction >= 1 {
            self.ramp = nil
            if !ducked { saved = nil; expected = nil }
        }
    }
    private func clearOwnership() {
        saved = nil; expected = nil; ramp = nil; ducked = false
        overridden = false; recovering = false; restorationRequested = false
    }
    private func restoreImmediately(current: VolumeState) throws {
        validateOwnership(current)
        if !overridden, let saved, expected != nil { try audio.write(saved) }
        clearOwnership()
    }
    func stop() {
        // Disable/quit/sleep restoration is immediate and best effort. If audio
        // is temporarily unavailable while the process lives, retry on a tick.
        candidate = nil; candidateClosing = nil
        restorationRequested = true
        do {
            try restoreImmediately(current: audio.read())
            status = enabled ? "Ready" : "Disabled"
        } catch {
            recovering = true
            status = "Audio unavailable: \(error.localizedDescription)"
        }
    }
}
struct AudioFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
