import XCTest
@testable import LidDuck

private final class WorkerOnlyLoginItem: LoginItemDriver {
    private var current: LoginItemStatus = .disabled
    var beforeFirstRead: (() -> Void)?
    var fails = false
    var status: LoginItemStatus {
        XCTAssertFalse(Thread.isMainThread, "System queries must not block the UI thread")
        let pause = beforeFirstRead; beforeFirstRead = nil; pause?()
        return current
    }
    func register() throws {
        XCTAssertFalse(Thread.isMainThread)
        if fails { throw AudioFailure(message: "Registration failed") }
        current = .enabled
    }
    func unregister() throws {
        XCTAssertFalse(Thread.isMainThread)
        current = .disabled
    }
}
final class LoginItemServiceTests: XCTestCase {
    func testSlowFirstLookupDoesNotBlockCallerOrMainQueue() {
        let gate = DispatchSemaphore(value: 0)
        let done = expectation(description: "Lookup snapshot")
        let mainResponsive = expectation(description: "Main queue stays responsive")
        let service = LoginItemService {
            XCTAssertFalse(Thread.isMainThread, "Driver must be constructed on the worker")
            let driver = WorkerOnlyLoginItem()
            driver.beforeFirstRead = { _ = gate.wait(timeout: .now() + 3) }
            return driver
        }
        let started = ProcessInfo.processInfo.systemUptime
        service.refresh { snapshot in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(snapshot.status, .disabled)
            done.fulfill()
        }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 0.5)
        DispatchQueue.main.async { mainResponsive.fulfill(); gate.signal() }
        wait(for: [mainResponsive, done], timeout: 5)
    }
    func testChangesAreSerializedAndReturnIndependentSnapshots() {
        let registered = expectation(description: "Registration snapshot")
        let unregistered = expectation(description: "Unregistration snapshot")
        let service = LoginItemService { WorkerOnlyLoginItem() }
        service.setEnabled(true) { snapshot in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(snapshot.status, .enabled)
            registered.fulfill()
        }
        service.setEnabled(false) { snapshot in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(snapshot.status, .disabled)
            unregistered.fulfill()
        }
        wait(for: [registered, unregistered], timeout: 5, enforceOrder: true)
    }
    func testFailureReturnsActualStateAndErrorOnMainQueue() {
        let done = expectation(description: "Failed registration snapshot")
        let service = LoginItemService {
            let driver = WorkerOnlyLoginItem(); driver.fails = true; return driver
        }
        service.setEnabled(true) { snapshot in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(snapshot.status, .disabled)
            XCTAssertNotNil(snapshot.error)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }
}
