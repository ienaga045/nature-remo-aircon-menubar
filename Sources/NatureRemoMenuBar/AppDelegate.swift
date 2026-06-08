import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let client = NatureRemoClient()
    private let store = SettingsStore()
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusController(client: client, store: store)
        statusController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController?.stop()
    }
}
