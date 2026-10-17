import Foundation

// All engine calls are serialized by the app's main-thread timer.
struct VolumeState: Equatable {
    let device: UInt32
    let channels: [UInt32]
    let values: [Float]
    var muted: Bool? = nil
    func matches(_ other: Self) -> Bool {
        muted == other.muted && device == other.device && channels == other.channels && values.count == other.values.count && zip(values, other.values).allSatisfy { abs($0 - $1) < 0.002 }
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
    private var saved: VolumeState?
    private var expected: VolumeState?
    private var ramp: (start: VolumeState, end: VolumeState, time: Double)?
    init(audio: VolumeIO) { self.audio = audio }

    func tick(angle: Double?, now: Double) {
        do {
            let current = try audio.read()
            if let expected, !expected.matches(current) {
                // Includes manual changes and output-route changes. Never write an old
                // device's volume onto the newly selected output.
                saved = nil; ramp = nil; self.expected = nil
                if ducked { overridden = true; status = "Manual override — reopen lid to rearm" }
            }
            if !enabled || angle == nil {
                candidate = nil; candidateClosing = nil
                try release(current: current, now: now)
                try advance(now: now)
                status = enabled ? "Lid sensor unavailable" : "Disabled"
                return
            }
            try advance(now: now)
            // Derive the current healthy state on every successful sample, so
            // re-enabling or recovering a sensor never leaves stale status text.
            status = overridden ? "Manual override — reopen lid to rearm" : (ducked ? "Ducked" : "Ready")
            let closing = !ducked && angle! < trigger
            let opening = ducked && angle! > restore
            if closing || opening {
                if candidateClosing != closing { candidate = now; candidateClosing = closing }
                if let candidate, now - candidate >= 0.25 {
                    self.candidate = nil; candidateClosing = nil
                    if closing {
                        let actual = try audio.read()
                        saved = actual; expected = actual; ducked = true; overridden = false
                        // Ducking can only reduce each channel; preserve channel balance.
                        let peak = actual.values.max() ?? 0
                        let scale: Float = peak > 0 ? min(1, duck / peak) : 1
                        let target = VolumeState(device: actual.device, channels: actual.channels, values: actual.values.map { $0 * scale })
                        ramp = (actual, target, now); status = "Ducked"
                    } else {
                        try release(current: try audio.read(), now: now)
                        status = "Ready"
                    }
                }
            } else { candidate = nil; candidateClosing = nil }
        } catch {
            saved = nil; expected = nil; ramp = nil; ducked = false
            candidate = nil; candidateClosing = nil
            status = "Audio unavailable: \(error.localizedDescription)"
        }
    }
    private func release(current: VolumeState, now: Double) throws {
        guard ducked else { return }
        ducked = false
        if !overridden, let saved, let expected, expected.matches(current) {
            ramp = (current, saved, now)
        } else { ramp = nil; expected = nil }
        saved = nil; overridden = false
    }
    private func advance(now: Double) throws {
        guard let ramp else { return }
        let fraction = Float(duration <= 0 ? 1 : min(1, max(0, (now - ramp.time) / duration)))
        let next = VolumeState(device: ramp.end.device, channels: ramp.end.channels, values: zip(ramp.start.values, ramp.end.values).map { $0 + ($1 - $0) * fraction })
        try audio.write(next)
        // Use the actual hardware value to tolerate driver quantization.
        let actual = try audio.read()
        guard actual.device == next.device, actual.channels == next.channels,
              zip(actual.values, next.values).allSatisfy({ abs($0 - $1) < 0.02 }) else {
            throw AudioFailure(message: "Output changed during transition")
        }
        expected = actual
        if fraction >= 1 { self.ramp = nil; if !ducked { expected = nil } }
    }
    func stop() {
        // Best-effort immediate restore on disable/quit/sleep, only while we own it.
        defer { saved = nil; expected = nil; ramp = nil; ducked = false; overridden = false; candidate = nil; candidateClosing = nil }
        guard let current = try? audio.read(), let expected, expected.matches(current) else { return }
        if let saved, !overridden { try? audio.write(saved) }
        else if let ramp, !ducked { try? audio.write(ramp.end) }
    }
}
struct AudioFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
