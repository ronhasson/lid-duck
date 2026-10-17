import XCTest
@testable import LidDuck
final class FakeAudio: VolumeIO {
    var state = VolumeState(device: 1, channels: [0], values: [0.8])
    var writes = 0
    var reads = 0
    var failOnRead: Int?
    var failure = false
    func read() throws -> VolumeState {
        reads += 1
        if failure || reads == failOnRead { throw AudioFailure(message: "Transient failure") }
        return state
    }
    func write(_ state: VolumeState) throws { self.state = state; writes += 1 }
}
final class EngineTests: XCTestCase {
    func setup() -> (FakeAudio, DuckEngine) {
        let audio = FakeAudio(); let engine = DuckEngine(audio: audio); engine.duration = 0
        return (audio, engine)
    }
    func close(_ e: DuckEngine) { e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.26); e.tick(angle: 60, now: 0.3) }
    func testRecloseDuringRestoreKeepsOriginalBaseline() {
        let (a,e) = setup(); close(e); e.duration = 2
        e.tick(angle: 90, now: 1); e.tick(angle: 90, now: 1.3)
        e.tick(angle: 60, now: 1.4); e.tick(angle: 60, now: 1.7)
        e.tick(angle: 60, now: 3.8)
        e.tick(angle: 90, now: 4); e.tick(angle: 90, now: 4.3); e.tick(angle: 90, now: 6.4)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testTransientReadPreservesValidatedBaseline() {
        let (a,e) = setup(); close(e)
        a.failure = true; e.tick(angle: 90, now: 1)
        a.failure = false; e.tick(angle: 90, now: 1.1); e.tick(angle: 90, now: 1.4); e.tick(angle: 90, now: 1.5)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testReadbackFailureRecoversAfterSuccessfulWrite() {
        let (a,e) = setup(); close(e); e.duration = 1
        e.tick(angle: 90, now: 1); e.tick(angle: 90, now: 1.3)
        a.failOnRead = a.reads + 3
        e.tick(angle: 90, now: 1.8)
        XCTAssertTrue(e.status.hasPrefix("Audio unavailable:"))
        e.tick(angle: 90, now: 1.9); e.tick(angle: 90, now: 3)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testManualChangeDuringOutageCancelsRestore() {
        let (a,e) = setup(); close(e)
        a.failure = true; e.tick(angle: 60, now: 1)
        a.state = VolumeState(device: 1, channels: [0], values: [0.4])
        a.failure = false; e.tick(angle: 60, now: 1.1); e.stop()
        XCTAssertEqual(a.state.values[0], 0.4)
    }
    func testDisableRetriesRestorationAfterReadFailure() {
        let (a,e) = setup(); close(e); a.failure = true
        e.enabled = false; e.stop()
        a.failure = false; e.tick(angle: 60, now: 1)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testStatusRecoversWithoutLidMovement() {
        let (_,e) = setup()
        e.enabled = false; e.tick(angle: 100, now: 0)
        XCTAssertEqual(e.status, "Disabled")
        e.enabled = true; e.tick(angle: 100, now: 0.05)
        XCTAssertEqual(e.status, "Ready")
        e.tick(angle: nil, now: 0.1)
        e.tick(angle: 100, now: 0.15)
        XCTAssertEqual(e.status, "Ready")
    }
    func testDebounceAndHysteresis() {
        let (a,e) = setup()
        e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.2)
        XCTAssertEqual(a.state.values[0], 0.8)
        e.tick(angle: 75, now: 0.21); e.tick(angle: 60, now: 0.3); e.tick(angle: 60, now: 0.56); e.tick(angle: 75, now: 0.6)
        XCTAssertEqual(a.state.values[0], 0.15, accuracy: 0.001)
        e.tick(angle: 90, now: 0.7); e.tick(angle: 90, now: 0.96); e.tick(angle: 90, now: 1)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testManualOverrideDoesNotRestoreStaleValue() {
        let (a,e) = setup(); close(e)
        a.state = VolumeState(device: 1, channels: [0], values: [0.4])
        e.tick(angle: 60, now: 0.4); e.tick(angle: 90, now: 0.5); e.tick(angle: 90, now: 0.8); e.stop()
        XCTAssertEqual(a.state.values[0], 0.4)
        e.tick(angle: 60, now: 1); e.tick(angle: 60, now: 1.3); e.tick(angle: 60, now: 1.4); e.stop()
        XCTAssertEqual(a.state.values[0], 0.4, accuracy: 0.001)
    }
    func testMuteOverride() {
        let (a,e) = setup(); close(e)
        a.state.muted = true
        e.tick(angle: 60, now: 0.4); e.stop()
        XCTAssertEqual(a.state.values[0], 0.15, accuracy: 0.001)
        XCTAssertEqual(a.state.muted, true)
    }
    func testRouteChangeLeavesNewDeviceAlone() {
        let (a,e) = setup(); close(e)
        a.state = VolumeState(device: 2, channels: [0], values: [0.6])
        e.tick(angle: 60, now: 0.4); e.stop()
        XCTAssertEqual(a.state.device, 2); XCTAssertEqual(a.state.values[0], 0.6)
    }
    func testSensorFailureAndDisableRestore() {
        let (a,e) = setup(); close(e); e.tick(angle: nil, now: 0.5)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
        close(e); e.enabled = false; e.tick(angle: 60, now: 1)
        XCTAssertEqual(a.state.values[0], 0.8, accuracy: 0.001)
    }
    func testRampAndManualInterruption() {
        let (a,e) = setup(); e.duration = 1
        e.tick(angle: 60, now: 0); e.tick(angle: 60, now: 0.26); e.tick(angle: 60, now: 0.76)
        XCTAssertEqual(a.state.values[0], 0.475, accuracy: 0.001)
        a.state = VolumeState(device: 1, channels: [0], values: [0.3])
        e.tick(angle: 60, now: 0.8); e.tick(angle: 90, now: 1); e.tick(angle: 90, now: 1.3); e.stop()
        XCTAssertEqual(a.state.values[0], 0.3)
    }
    func testNeverRaisesQuietAudioAndPreservesBalance() {
        let (a,e) = setup(); a.state = VolumeState(device: 1, channels: [1,2], values: [0.1,0.05]); close(e)
        XCTAssertEqual(a.state.values, [0.1,0.05]); e.stop()
        a.state = VolumeState(device: 1, channels: [1,2], values: [0.8,0.4]); close(e)
        XCTAssertEqual(a.state.values[0], 0.15, accuracy: 0.001)
        XCTAssertEqual(a.state.values[1], 0.075, accuracy: 0.001)
        e.stop(); XCTAssertEqual(a.state.values, [0.8,0.4])
    }
}
