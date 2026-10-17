import XCTest
@testable import LidDuck

private final class FakeLoginItem: LoginItemDriver {
    var status = LoginItemStatus.disabled
    var registrationResult = LoginItemStatus.enabled
    var fails = false
    func register() throws {
        if fails { throw AudioFailure(message: "Registration failed") }
        status = registrationResult
    }
    func unregister() throws {
        if fails { throw AudioFailure(message: "Unregistration failed") }
        status = .disabled
    }
}
final class LoginItemTests: XCTestCase {
    func testApprovalAndExternalChangesReflectSystemState() {
        let driver = FakeLoginItem()
        let login = LoginItemController(driver: driver)
        XCTAssertEqual(login.status, .disabled)
        driver.registrationResult = .requiresApproval
        login.setEnabled(true)
        XCTAssertEqual(login.status, .requiresApproval)
        driver.status = .enabled; login.refresh()
        XCTAssertEqual(login.status, .enabled)
        driver.status = .disabled; login.refresh()
        XCTAssertEqual(login.status, .disabled)
    }
    func testFailedOperationsDoNotInventSuccess() {
        let driver = FakeLoginItem()
        let login = LoginItemController(driver: driver)
        driver.fails = true; login.setEnabled(true)
        XCTAssertEqual(login.status, .disabled)
        XCTAssertNotNil(login.error)
        driver.fails = false; login.setEnabled(true)
        XCTAssertEqual(login.status, .enabled)
        XCTAssertNil(login.error)
        driver.fails = true; login.setEnabled(false)
        XCTAssertEqual(login.status, .enabled)
        XCTAssertNotNil(login.error)
        driver.fails = false; login.setEnabled(false)
        XCTAssertEqual(login.status, .disabled)
        XCTAssertNil(login.error)
    }
}
