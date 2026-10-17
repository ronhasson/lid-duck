import SwiftUI
import AppKit
import ServiceManagement

final class AppModel: ObservableObject {
    @Published var angle: Double?
    @Published var status = "Starting"
    @Published var sensorStatus = ""
    @Published private(set) var loginStatus = LoginItemStatus.disabled
    @Published private(set) var loginError: String?
    @Published private(set) var loginBusy = false
    @Published private(set) var loginLoaded = false
    private let loginItem = LoginItemService(makeDriver: { SystemLoginItem() })
    // Bundle location is constant during this process; avoid filesystem work in
    // SwiftUI body evaluations (including live angle updates).
    let canRegisterLoginItem: Bool = {
        let app = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let folder = app.deletingLastPathComponent().path
        return app.pathExtension == "app" && (folder == "/Applications" || folder == NSHomeDirectory() + "/Applications")
    }()
    @Published var enabled: Bool { didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); if !enabled { engine.stop() }; configure(); poll() } }
    @Published var trigger: Double { didSet { if restore <= trigger { restore = trigger + 1 }; save() } }
    @Published var restore: Double { didSet { if restore <= trigger { trigger = restore - 1 }; save() } }
    @Published var duck: Double { didSet { save() } }
    @Published var duration: Double { didSet { save() } }
    private let engine = DuckEngine(audio: SystemVolume())
    private let sensor = LidSensor()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["enabled": true, "trigger": 70.0, "restore": 85.0, "duck": 15.0, "duration": 200.0])
        enabled = defaults.bool(forKey: "enabled")
        let t = defaults.double(forKey: "trigger"), r = defaults.double(forKey: "restore")
        let initialTrigger = t.isFinite ? min(179, max(1, t)) : 70
        trigger = initialTrigger
        restore = r.isFinite ? min(180, max(initialTrigger + 1, r)) : 85
        duck = min(100, max(0, defaults.double(forKey: "duck")))
        duration = min(2000, max(0, defaults.double(forKey: "duration")))
        configure()
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.engine.stop(); self?.timer?.invalidate(); self?.sensor.reset(); self?.angle = nil
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.startTimer() })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in self?.engine.stop() })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.refreshLoginItem() })
        refreshLoginItem()
        startTimer()
    }
    var loginRequested: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }
    func refreshLoginItem() {
        // Activation and onAppear can coincide. Coalesce them rather than queue
        // multiple potentially slow service queries behind the initial lookup.
        guard !loginBusy else { return }
        loginBusy = true
        loginItem.refresh { [weak self] snapshot in self?.applyLoginSnapshot(snapshot) }
    }
    private func applyLoginSnapshot(_ snapshot: LoginItemSnapshot) {
        loginStatus = snapshot.status; loginError = snapshot.error
        loginLoaded = true; loginBusy = false
    }
    func setLaunchAtLogin(_ enabled: Bool) {
        guard !loginBusy, loginLoaded else { return }
        guard !enabled || canRegisterLoginItem else {
            loginError = "Move Lid Duck to Applications and reopen it first."
            return
        }
        loginBusy = true
        loginItem.setEnabled(enabled) { [weak self] snapshot in self?.applyLoginSnapshot(snapshot) }
    }
    private func configure() {
        engine.enabled = enabled; engine.trigger = trigger; engine.restore = restore
        engine.duck = Float(duck / 100); engine.duration = duration / 1000
    }
    private func save() {
        let d = UserDefaults.standard
        d.set(trigger, forKey: "trigger"); d.set(restore, forKey: "restore")
        d.set(duck, forKey: "duck"); d.set(duration, forKey: "duration")
        configure()
    }
    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        poll()
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        let reading = sensor.read(now: now)
        engine.tick(angle: reading, now: now)
        // A stable sensor/status should not invalidate the popover 20 times/sec.
        if angle != reading { angle = reading }
        if sensorStatus != sensor.detail { sensorStatus = sensor.detail }
        if status != engine.status { status = engine.status }
    }
    var issue: String? {
        if angle == nil { return sensorStatus.isEmpty ? "Lid sensor unavailable" : sensorStatus }
        if status.hasPrefix("Audio unavailable:") { return status }
        return nil
    }
    var compactStatus: String {
        if issue != nil { return "Needs attention" }
        if !enabled { return "Disabled" }
        if status.hasPrefix("Manual override") { return "Manual override" }
        return status
    }
    func resetDefaults() {
        engine.stop()
        trigger = 70; restore = 85; duck = 15; duration = 200; enabled = true
        poll()
    }
    func quit() { engine.stop(); NSApplication.shared.terminate(nil) }
}

// A small template drawing stays crisp and follows the menu bar's appearance.
private enum LidIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let lid = NSBezierPath()
            lid.lineWidth = 1.6
            lid.lineCapStyle = .round
            lid.lineJoinStyle = .round
            // Side profile: a single lid meets the base at the hinge.
            lid.move(to: NSPoint(x: 5, y: 4))
            lid.line(to: NSPoint(x: 11, y: 14))
            lid.stroke()
            let base = NSBezierPath()
            base.lineWidth = 1.6
            base.lineCapStyle = .round
            base.move(to: NSPoint(x: 5, y: 4))
            base.line(to: NSPoint(x: 19, y: 4))
            base.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

@main
struct LidDuckApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                angleSetting("Trigger below", value: $model.trigger, range: 1...179)
                angleSetting("Restore above", value: $model.restore, range: 2...180)
                volumeSetting
                transitionSetting
                Text("Hold for 250 ms. Manual volume changes override ducking until the lid reopens.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Divider()
                loginSetting
                HStack {
                    Button { model.resetDefaults() } label: {
                        Image(systemName: "arrow.counterclockwise").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("Reset ducking settings to defaults")
                    .accessibilityLabel("Reset ducking settings to defaults")
                    Spacer()
                    Button("Quit") { model.quit() }.keyboardShortcut("q")
                }
            }.padding(EdgeInsets(top: 18, leading: 18, bottom: 12, trailing: 18)).frame(width: 330)
        } label: {
            Image(nsImage: LidIcon.image)
                .opacity(model.enabled ? 1 : 0.45)
                .accessibilityLabel("Lid Duck")
        }.menuBarExtraStyle(.window)
    }
    private var loginSetting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at login", isOn: Binding(
                get: { model.loginRequested },
                set: { model.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch).controlSize(.mini).font(.callout)
            .disabled(model.loginBusy || (!model.canRegisterLoginItem && !model.loginRequested))
            if !model.loginLoaded {
                Text("Checking login setting…").font(.caption).foregroundStyle(.secondary)
            } else if let error = model.loginError {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !model.canRegisterLoginItem {
                Text("Move to Applications to enable.").font(.caption).foregroundStyle(.secondary)
            }
            if model.loginStatus == .requiresApproval {
                HStack {
                    Text("Approval needed").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Settings") { SMAppService.openSystemSettingsLoginItems() }
                        .buttonStyle(.borderless).font(.caption)
                }
            } else if model.canRegisterLoginItem && model.loginStatus == .unavailable {
                Text("Login item unavailable. Reopen the installed app and try again.")
                    .font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.onAppear { model.refreshLoginItem() }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle("Enable Lid Duck", isOn: $model.enabled)
                    .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                    .tint(model.issue != nil ? .red : .accentColor)
                    .fixedSize()
                    .help(model.enabled ? "Disable Lid Duck" : "Enable Lid Duck")
                Circle()
                    .fill(model.issue != nil ? Color.red : (model.enabled ? Color.green : Color.secondary))
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(model.compactStatus).font(.callout.weight(.medium)).lineLimit(1)
                Spacer(minLength: 0)
                Text(model.angle.map { "\(Int($0))°" } ?? "—°")
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(model.issue != nil ? Color.red : Color.primary)
                    .accessibilityLabel(model.angle.map { "Lid angle \(Int($0)) degrees" } ?? "Lid angle unavailable")
            }
            if let issue = model.issue {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    private func valueLabel(_ value: String) -> some View {
        Text(value).font(.system(.callout, design: .rounded).weight(.medium))
            .monospacedDigit().foregroundStyle(Color.accentColor)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
    }
    private func angleSetting(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(title).font(.callout); Spacer(); valueLabel("\(Int(value.wrappedValue))°") }
            SettingSlider(title, value: value, in: range)
        }
    }
    private var volumeSetting: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Duck volume").font(.callout)
                Spacer()
                valueLabel("\(Int(model.duck))%")
            }
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                SettingSlider("Duck volume", value: $model.duck, in: 0...100)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }.font(.caption)
        }
    }
    private var transitionSetting: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Transition").font(.callout)
                Spacer()
                valueLabel("\(Int(model.duration)) ms")
            }
            SettingSlider("Transition duration in milliseconds", value: $model.duration, in: 0...2000)
            // Whole-millisecond values use a continuous native slider; this ruler
            // has only nine marks instead of 2,001 native tick positions.
            GeometryReader { geometry in
                let trackWidth = max(0, geometry.size.width - 16)
                ForEach(0..<9) { index in
                    let major = index.isMultiple(of: 2)
                    VStack(spacing: 3) {
                        Rectangle().fill(Color.secondary.opacity(major ? 0.65 : 0.35))
                            .frame(width: 1, height: major ? 7 : 4)
                        if major {
                            Text(index == 0 ? "0" : "\(index * 250)")
                                .font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .position(x: 8 + trackWidth * Double(index) / 8, y: major ? 11 : 3)
                }
            }.frame(height: 24).accessibilityHidden(true)
        }
    }
}
