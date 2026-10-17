import Foundation

struct LoginItemSnapshot: Sendable {
    let status: LoginItemStatus
    let error: String?
}

// The driver and synchronous controller are created and used exclusively on this
// serial worker. Only immutable snapshots cross back to the main queue. Neither
// construction nor a menu's onAppear performs ServiceManagement work inline.
final class LoginItemService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "local.lid-duck.login-item", qos: .utility)
    private let makeDriver: () -> LoginItemDriver
    private var controller: LoginItemController?

    init(makeDriver: @escaping () -> LoginItemDriver) {
        self.makeDriver = makeDriver
    }
    func refresh(completion: @escaping (LoginItemSnapshot) -> Void) {
        perform(change: nil, completion: completion)
    }
    func setEnabled(_ enabled: Bool, completion: @escaping (LoginItemSnapshot) -> Void) {
        perform(change: enabled, completion: completion)
    }
    private func perform(change: Bool?, completion: @escaping (LoginItemSnapshot) -> Void) {
        queue.async {
            let controller: LoginItemController
            if let existing = self.controller {
                controller = existing
            } else {
                controller = LoginItemController(driver: self.makeDriver())
                self.controller = controller
            }
            if let change { controller.setEnabled(change) }
            else { controller.refresh() }
            let snapshot = LoginItemSnapshot(status: controller.status, error: controller.error)
            DispatchQueue.main.async { completion(snapshot) }
        }
    }
}
