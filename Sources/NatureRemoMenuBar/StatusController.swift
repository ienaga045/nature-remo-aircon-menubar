import AppKit

@MainActor
final class StatusController: NSObject {
    private let client: NatureRemoClient
    private let store: SettingsStore
    private let loginItemManager = LoginItemManager()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var preferencesWindowController: PreferencesWindowController?
    private var appliances: [Appliance] = []
    private var devices: [RemoDevice] = []
    private var localStates: [String: AirconDisplayState] = [:]
    private let localStateDisplayDuration: TimeInterval = 20
    private let automaticRefreshInterval: TimeInterval = 60
    private let menuOpenRefreshMinimumInterval: TimeInterval = 5
    private var temperatureSliderViews: [TemperatureSliderView] = []
    private var refreshTimer: Timer?
    private var lastRefreshDate = Date.distantPast
    private var isLoading = false

    init(client: NatureRemoClient, store: SettingsStore) {
        self.client = client
        self.store = store
        super.init()
    }

    func start() {
        statusItem.button?.title = "Remo"
        statusItem.button?.image = NSImage(systemSymbolName: "fan", accessibilityDescription: "Nature Remo")
        statusItem.button?.imagePosition = .imageLeading
        rebuildMenu(status: "読み込み中...")
        startAutomaticRefresh()
        Task { await refresh(clearLocalStates: true) }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func rebuildMenu(status: String? = nil) {
        let menu = NSMenu()
        temperatureSliderViews = []

        if let status {
            let item = NSMenuItem(title: status, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            menu.addItem(.separator())
        }

        if store.loadToken() == nil {
            menu.addItem("APIトークンを設定...", action: #selector(openPreferences), target: self, keyEquivalent: ",")
            menu.addItem(.separator())
            addUtilityItems(to: menu)
            menu.addItem(.separator())
            menu.addItem("終了", action: #selector(quit), target: self, keyEquivalent: "q")
            install(menu)
            return
        }

        if devices.isEmpty {
            let item = NSMenuItem(title: "Nature Remoが見つかりません", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            addDeviceMenu(to: menu, devices: devices)
        }

        menu.addItem(.separator())

        let aircons = appliances.filter(\.isAircon)
        if aircons.isEmpty {
            let item = NSMenuItem(title: "エアコンが見つかりません", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            statusItem.button?.title = menuBarTitle()
        } else {
            addApplianceMenu(to: menu, aircons: aircons)
            menu.addItem(.separator())
            addControls(to: menu, appliance: selectedAppliance(from: aircons))
        }

        menu.addItem(.separator())
        addUtilityItems(to: menu)
        menu.addItem(.separator())
        menu.addItem("終了", action: #selector(quit), target: self, keyEquivalent: "q")
        install(menu)
    }

    private func install(_ menu: NSMenu) {
        menu.delegate = self
        statusItem.menu = menu
    }

    private func startAutomaticRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: automaticRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refresh(clearLocalStates: true)
            }
        }
    }

    private func addUtilityItems(to menu: NSMenu) {
        menu.addItem("更新", action: #selector(refreshFromMenu), target: self, keyEquivalent: "r")
        menu.addItem("設定...", action: #selector(openPreferences), target: self, keyEquivalent: ",")

        let loginItem = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = loginItemManager.menuState
        menu.addItem(loginItem)
    }

    private func addDeviceMenu(to menu: NSMenu, devices: [RemoDevice]) {
        let deviceMenu = NSMenu()
        let selectedID = selectedDevice(from: devices)?.id

        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.id
            item.state = device.id == selectedID ? .on : .off
            deviceMenu.addItem(item)
        }

        let parent = NSMenuItem(title: "Nature Remo", action: nil, keyEquivalent: "")
        parent.submenu = deviceMenu
        menu.addItem(parent)
    }

    private func addApplianceMenu(to menu: NSMenu, aircons: [Appliance]) {
        let applianceMenu = NSMenu()
        let selectedID = selectedAppliance(from: aircons)?.id

        for appliance in aircons {
            let item = NSMenuItem(title: appliance.nickname, action: #selector(selectAppliance(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = appliance.id
            item.state = appliance.id == selectedID ? .on : .off
            applianceMenu.addItem(item)
        }

        let parent = NSMenuItem(title: "エアコン", action: nil, keyEquivalent: "")
        parent.submenu = applianceMenu
        menu.addItem(parent)
    }

    private func addControls(to menu: NSMenu, appliance: Appliance?) {
        guard let appliance else { return }

        let displayState = currentDisplayState(for: appliance)
        let currentMode = displayState.mode
        let currentTemp = displayState.temperature
        statusItem.button?.title = menuBarTitle(displayState: displayState)

        let sliderView = TemperatureSliderView(
            temperatures: defaultTemperatures(for: appliance, mode: currentMode),
            currentTemperature: currentTemp
        ) { [weak self] temperature in
            self?.send(ControlPayload(applianceID: appliance.id, mode: currentMode, temperature: temperature))
        }
        temperatureSliderViews.append(sliderView)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
        menu.addItem(.separator())

        let onItem = NSMenuItem(title: "ON", action: #selector(turnOn), keyEquivalent: "")
        onItem.target = self
        onItem.representedObject = ControlPayload(applianceID: appliance.id, mode: currentMode, temperature: currentTemp)
        menu.addItem(onItem)

        let offItem = NSMenuItem(title: "OFF", action: #selector(turnOff), keyEquivalent: "")
        offItem.target = self
        offItem.representedObject = appliance.id
        menu.addItem(offItem)

        let modeMenu = NSMenu()
        for mode in OperationMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(setMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ControlPayload(applianceID: appliance.id, mode: mode, temperature: currentTemp)
            item.state = mode == currentMode ? .on : .off
            modeMenu.addItem(item)
        }
        let modeParent = NSMenuItem(title: "運転モード", action: nil, keyEquivalent: "")
        modeParent.submenu = modeMenu
        menu.addItem(modeParent)
    }

    private func selectedAppliance(from aircons: [Appliance]) -> Appliance? {
        if let selectedID = store.selectedApplianceID, let selected = aircons.first(where: { $0.id == selectedID }) {
            return selected
        }

        let first = aircons.first
        store.selectedApplianceID = first?.id
        return first
    }

    private func selectedDevice(from devices: [RemoDevice]) -> RemoDevice? {
        if let selectedID = store.selectedDeviceID, let selected = devices.first(where: { $0.id == selectedID }) {
            return selected
        }

        let first = devices.first
        store.selectedDeviceID = first?.id
        return first
    }

    private func defaultTemperatures(for appliance: Appliance, mode: OperationMode) -> [String] {
        if let temps = appliance.aircon?.range?.modes?[mode.rawValue]?.temp, !temps.isEmpty {
            return temps.sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }
        }

        return (16...30).map(String.init)
    }

    private func token() throws -> String {
        guard let token = store.loadToken(), !token.isEmpty else {
            throw NatureRemoError.missingToken
        }
        return token
    }

    private func currentDisplayState(for appliance: Appliance) -> AirconDisplayState {
        if let localState = localStates[appliance.id] {
            if Date().timeIntervalSince(localState.updatedAt) < localStateDisplayDuration {
                return localState
            }

            localStates.removeValue(forKey: appliance.id)
        }

        let mode = OperationMode(rawValue: appliance.aircon?.settings?.mode ?? "") ?? .cool
        let temperature = appliance.aircon?.settings?.temp
            ?? store.lastTemperature(for: appliance.id)
            ?? defaultTemperatures(for: appliance, mode: mode).first
            ?? "25"
        let isOff = appliance.aircon?.settings?.button == "power-off"
        return AirconDisplayState(mode: mode, temperature: temperature, isOff: isOff, updatedAt: .distantPast)
    }

    private func send(_ payload: ControlPayload, powerOff: Bool = false) {
        rebuildMenu(status: "送信中...")
        Task {
            do {
                let token = try token()
                try await client.updateAircon(
                    applianceID: payload.applianceID,
                    token: token,
                    powerOff: powerOff,
                    mode: powerOff ? nil : payload.mode,
                    temperature: powerOff ? nil : payload.temperature
                )
                applyLocalState(payload, powerOff: powerOff)
                rebuildMenu(status: "送信しました")
            } catch {
                rebuildMenu(status: error.localizedDescription)
            }
        }
    }

    private func applyLocalState(_ payload: ControlPayload, powerOff: Bool) {
        let previous = localStates[payload.applianceID]
        let appliance = appliances.first { $0.id == payload.applianceID }
        let fallbackState = appliance.map(currentDisplayState(for:))
        let mode = payload.mode ?? previous?.mode ?? fallbackState?.mode ?? .cool
        let temperature = payload.temperature ?? previous?.temperature ?? fallbackState?.temperature ?? "25"
        localStates[payload.applianceID] = AirconDisplayState(mode: mode, temperature: temperature, isOff: powerOff, updatedAt: Date())
        store.saveLastTemperature(temperature, for: payload.applianceID)
    }

    private func refresh(status: String? = nil, clearLocalStates: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if clearLocalStates {
            localStates.removeAll()
        }

        do {
            let token = try token()
            async let fetchedAppliances = client.appliances(token: token)
            async let fetchedDevices = client.devices(token: token)
            appliances = try await fetchedAppliances
            devices = try await fetchedDevices
            lastRefreshDate = Date()
            rebuildMenu(status: status)
        } catch {
            statusItem.button?.title = "Remo"
            rebuildMenu(status: error.localizedDescription)
        }
    }

    private func formatTemperature(_ temperature: Double) -> String {
        if temperature.rounded() == temperature {
            return String(Int(temperature))
        }

        return String(format: "%.1f", temperature)
    }

    private func menuBarTitle(displayState: AirconDisplayState? = nil) -> String {
        let temperatureTitle: String
        if let roomTemperature = selectedDevice(from: devices)?.roomTemperature {
            temperatureTitle = "室温 \(formatTemperature(roomTemperature))℃"
        } else {
            temperatureTitle = "室温 --℃"
        }

        guard let displayState else {
            return temperatureTitle
        }

        return "\(temperatureTitle) /\(displayState.powerTitle)"
    }

    @objc private func refreshFromMenu() {
        rebuildMenu(status: "読み込み中...")
        Task { await refresh(clearLocalStates: true) }
    }

    @objc private func selectAppliance(_ sender: NSMenuItem) {
        store.selectedApplianceID = sender.representedObject as? String
        rebuildMenu()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        store.selectedDeviceID = sender.representedObject as? String
        rebuildMenu()
    }

    @objc private func turnOn(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ControlPayload else { return }
        send(payload)
    }

    @objc private func turnOff(_ sender: NSMenuItem) {
        guard let applianceID = sender.representedObject as? String else { return }
        send(ControlPayload(applianceID: applianceID, mode: nil, temperature: nil), powerOff: true)
    }

    @objc private func setMode(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ControlPayload else { return }
        send(payload)
    }

    @objc private func setTemperature(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ControlPayload else { return }
        send(payload)
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            let controller = PreferencesWindowController(store: store)
            controller.delegate = self
            preferencesWindowController = controller
        }

        preferencesWindowController?.showWindow(nil)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try loginItemManager.setEnabled(!loginItemManager.isEnabled)
            rebuildMenu(status: loginItemManager.statusMessage)
        } catch {
            rebuildMenu(status: error.localizedDescription)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension StatusController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        guard Date().timeIntervalSince(lastRefreshDate) >= menuOpenRefreshMinimumInterval else {
            return
        }

        Task { await refresh(clearLocalStates: true) }
    }
}

extension StatusController: PreferencesWindowControllerDelegate {
    func preferencesDidSave() {
        rebuildMenu(status: "読み込み中...")
        Task { await refresh() }
    }
}

private struct ControlPayload {
    let applianceID: String
    let mode: OperationMode?
    let temperature: String?
}

private struct AirconDisplayState {
    let mode: OperationMode
    let temperature: String
    let isOff: Bool
    let updatedAt: Date

    var powerTitle: String {
        isOff ? "OFF" : "ON"
    }
}

private extension NSMenu {
    func addItem(_ title: String, action: Selector?, target: AnyObject?, keyEquivalent: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        addItem(item)
    }
}
