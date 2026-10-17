import Foundation

enum LoginItemStatus: Equatable, Sendable {
    case enabled, disabled, requiresApproval, unavailable
}
protocol LoginItemDriver: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}
// Read system state after every operation, even a failure. No separate persisted
// Boolean can get out of sync with changes made in System Settings.
final class LoginItemController {
    private let driver: LoginItemDriver
    private(set) var status: LoginItemStatus
    private(set) var error: String?
    init(driver: LoginItemDriver) { self.driver = driver; status = driver.status }
    func refresh() {
        let current = driver.status
        if current != status { error = nil }
        status = current
    }
    func setEnabled(_ enabled: Bool) {
        error = nil
        do {
            if enabled { try driver.register() } else { try driver.unregister() }
        } catch { self.error = error.localizedDescription }
        // Preserve an error from this operation even if the driver also changed
        // state. A later external state change can clear it via refresh().
        status = driver.status
    }
}
