import Foundation

final class MemoryAudio: VolumeIO {
    var state = VolumeState(device: 1, channels: [0], values: [0.8])
    var failure = false
    var reads = 0
    var failOnRead: Int?
    func read() throws -> VolumeState {
        reads += 1
        if failure || reads == failOnRead { throw AudioFailure(message: "Disconnected") }; return state
    }
    func write(_ state: VolumeState) throws { self.state = state }
}
final class MemoryLogin: LoginItemDriver {
    var status: LoginItemStatus = .disabled
    var registrationResult: LoginItemStatus = .enabled
    var failure = false
    func register() throws {
        if failure { throw AudioFailure(message: "Registration failed") }
        status = registrationResult
    }
    func unregister() throws {
        if failure { throw AudioFailure(message: "Unregistration failed") }
        status = .disabled
    }
}
final class SlowWorkerLogin: LoginItemDriver {
    private var first = true
    private var current = LoginItemStatus.disabled
    let gate: DispatchSemaphore
    init(gate: DispatchSemaphore) {
        precondition(!Thread.isMainThread)
        self.gate = gate
    }
    var status: LoginItemStatus {
        precondition(!Thread.isMainThread)
        if first { first = false; _ = gate.wait(timeout: .now() + 3) }
        return current
    }
    func register() throws { precondition(!Thread.isMainThread); current = .enabled }
    func unregister() throws { precondition(!Thread.isMainThread); current = .disabled }
}
@main struct EngineChecks {
    static func main() {
        func make() -> (MemoryAudio, DuckEngine) {
            let a = MemoryAudio(); let e = DuckEngine(audio: a); e.duration = 0; return (a,e)
        }
        func close(_ e: DuckEngine) { e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.26); e.tick(angle: 60, now: 0.3) }
        func near(_ a: Float, _ b: Float) { precondition(abs(a-b) < 0.001, "Volume mismatch: \(a) vs \(b)") }
        do {
            let (a,e) = make()
            e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.2); near(a.state.values[0], 0.8)
            e.tick(angle: 75, now: 0.21); e.tick(angle: 60, now: 0.3); e.tick(angle: 60, now: 0.5); near(a.state.values[0], 0.8)
            e.tick(angle: 60, now: 0.56); e.tick(angle: 75, now: 0.6); near(a.state.values[0], 0.15)
            e.tick(angle: 90, now: 0.7); e.tick(angle: 90, now: 0.96); e.tick(angle: 90, now: 1); near(a.state.values[0], 0.8)
        }
        do {
            let (a,e) = make(); close(e)
            a.state = VolumeState(device: 1, channels: [0], values: [0.4])
            e.tick(angle: 60, now: 0.4); e.tick(angle: 90, now: 0.5); e.tick(angle: 90, now: 0.8); e.stop(); near(a.state.values[0], 0.4)
            e.tick(angle: 60, now: 1); e.tick(angle: 60, now: 1.3); e.tick(angle: 60, now: 1.4); e.stop(); near(a.state.values[0], 0.4)
        }
        do {
            let (a,e) = make(); close(e); a.state.muted = true
            e.tick(angle: 60, now: 0.4); e.stop(); near(a.state.values[0], 0.15); precondition(a.state.muted == true)
        }
        do {
            let (a,e) = make(); close(e); a.state = VolumeState(device: 2, channels: [0], values: [0.6])
            e.tick(angle: 60, now: 0.4); e.stop(); precondition(a.state.device == 2); near(a.state.values[0], 0.6)
        }
        do {
            let (a,e) = make(); close(e); e.tick(angle: nil, now: 0.5); near(a.state.values[0], 0.8)
            close(e); e.enabled = false; e.tick(angle: 60, now: 1); near(a.state.values[0], 0.8)
        }
        do {
            let (a,e) = make(); e.duration = 1
            e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.26); e.tick(angle: 60, now: 0.76); near(a.state.values[0], 0.475)
            a.state = VolumeState(device: 1, channels: [0], values: [0.3]); e.tick(angle: 60, now: 0.8); e.stop(); near(a.state.values[0], 0.3)
        }
        do {
            let (a,e) = make(); a.state = VolumeState(device: 1, channels: [1,2], values: [0.1,0.05]); close(e); near(a.state.values[0], 0.1); e.stop()
            a.state = VolumeState(device: 1, channels: [1,2], values: [0.8,0.4]); close(e)
            near(a.state.values[0], 0.15); near(a.state.values[1], 0.075); e.stop(); precondition(a.state.values == [0.8,0.4])
        }
        do {
            let (a,e) = make(); close(e); a.failure = true; e.tick(angle: 60, now: 0.4)
            a.failure = false; a.state = VolumeState(device: 2, channels: [0], values: [0.5]); e.stop(); near(a.state.values[0], 0.5)
        }
        do {
            let (a,e) = make(); close(e); e.duration = 1
            e.tick(angle: 90, now: 0.4); e.tick(angle: 90, now: 0.7); e.tick(angle: 90, now: 1.2)
            near(a.state.values[0], 0.475)
            a.state = VolumeState(device: 1, channels: [0], values: [0.25])
            e.tick(angle: 90, now: 1.3); e.stop(); near(a.state.values[0], 0.25)
        }
        do {
            let (a,e) = make(); close(e); e.duration = 1
            e.tick(angle: 90, now: 0.4); e.tick(angle: 90, now: 0.7); e.stop(); near(a.state.values[0], 0.8)
        }
        do {
            let (_,e) = make()
            e.enabled = false; e.tick(angle: 100, now: 0)
            precondition(e.status == "Disabled")
            e.enabled = true; e.tick(angle: 100, now: 0.05)
            precondition(e.status == "Ready", "Re-enable must clear Disabled without lid movement")
            e.tick(angle: nil, now: 0.1)
            precondition(e.status == "Lid sensor unavailable")
            e.tick(angle: 100, now: 0.15)
            precondition(e.status == "Ready", "Sensor recovery must clear the unavailable status")
        }
        do {
            let (a,e) = make(); close(e); e.duration = 2
            e.tick(angle: 90, now: 1); e.tick(angle: 90, now: 1.3)
            e.tick(angle: 60, now: 1.4); e.tick(angle: 60, now: 1.7)
            e.tick(angle: 60, now: 3.8)
            e.tick(angle: 90, now: 4); e.tick(angle: 90, now: 4.3); e.tick(angle: 90, now: 6.4)
            near(a.state.values[0], 0.8)
        }
        do {
            let (a,e) = make(); close(e)
            a.failure = true; e.tick(angle: 90, now: 1)
            a.failure = false; e.tick(angle: 90, now: 1.1); e.tick(angle: 90, now: 1.4); e.tick(angle: 90, now: 1.5)
            near(a.state.values[0], 0.8)
        }
        do {
            let (a,e) = make(); close(e)
            a.failure = true; e.tick(angle: 60, now: 1)
            a.state = VolumeState(device: 1, channels: [0], values: [0.4])
            a.failure = false; e.tick(angle: 60, now: 1.1); e.stop()
            near(a.state.values[0], 0.4)
        }
        do {
            let (a,e) = make(); close(e); e.duration = 1
            e.tick(angle: 90, now: 1); e.tick(angle: 90, now: 1.3)
            a.failOnRead = a.reads + 3
            e.tick(angle: 90, now: 1.8)
            precondition(e.status.hasPrefix("Audio unavailable:"))
            e.tick(angle: 90, now: 1.9); e.tick(angle: 90, now: 3)
            near(a.state.values[0], 0.8)
        }
        do {
            let (a,e) = make(); close(e); a.failure = true
            e.enabled = false; e.stop()
            a.failure = false; e.tick(angle: 60, now: 1)
            near(a.state.values[0], 0.8)
        }
        do {
            let driver = MemoryLogin(); let login = LoginItemController(driver: driver)
            precondition(login.status == .disabled)
            driver.registrationResult = .requiresApproval
            login.setEnabled(true); precondition(login.status == .requiresApproval)
            driver.status = .enabled; login.refresh(); precondition(login.status == .enabled)
            driver.failure = true; login.setEnabled(false)
            precondition(login.status == .enabled && login.error != nil)
            driver.failure = false; login.setEnabled(false)
            precondition(login.status == .disabled && login.error == nil)
            driver.failure = true; login.setEnabled(true)
            precondition(login.status == .disabled && login.error != nil)
        }
        do {
            let gate = DispatchSemaphore(value: 0)
            let service = LoginItemService { SlowWorkerLogin(gate: gate) }
            var snapshots: [LoginItemStatus] = []
            var mainResponsive = false
            let started = ProcessInfo.processInfo.systemUptime
            service.refresh { snapshot in
                precondition(Thread.isMainThread); snapshots.append(snapshot.status)
            }
            precondition(ProcessInfo.processInfo.systemUptime - started < 0.5, "Slow login query blocked the caller")
            service.setEnabled(true) { snapshot in
                precondition(Thread.isMainThread); snapshots.append(snapshot.status)
            }
            service.setEnabled(false) { snapshot in
                precondition(Thread.isMainThread); snapshots.append(snapshot.status)
            }
            DispatchQueue.main.async { mainResponsive = true; gate.signal() }
            let deadline = Date().addingTimeInterval(5)
            while snapshots.count < 3 && Date() < deadline {
                _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
            }
            precondition(mainResponsive && snapshots == [.disabled, .enabled, .disabled], "Login worker must keep the UI responsive and serialize snapshots")
        }
        print("PASS: debounce/reset, hysteresis/restore, manual override/rearm, mute override, route switch, sensor loss, disable, fade interruption, quiet audio, channel balance, audio failure, re-enable status, sensor recovery status, interrupted restore baseline, transient read recovery, manual changes during outage, readback failure, deferred disable restore, login registration/approval/errors, nonblocking cold login lookup, serialized main-queue snapshots")
    }
}
