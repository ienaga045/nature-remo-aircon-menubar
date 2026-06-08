import AppKit

@MainActor
protocol PreferencesWindowControllerDelegate: AnyObject {
    func preferencesDidSave()
}

final class PreferencesWindowController: NSWindowController {
    weak var delegate: PreferencesWindowControllerDelegate?

    private let store: SettingsStore
    private let tokenField = NSSecureTextField(frame: .zero)
    private let messageLabel = NSTextField(labelWithString: "")

    init(store: SettingsStore) {
        self.store = store

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Nature Remo 設定"
        window.center()
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        tokenField.stringValue = store.loadToken() ?? ""
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "Nature Remo Cloud APIトークン")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let helpLabel = NSTextField(wrappingLabelWithString: "home.nature.global で発行したアクセストークンを保存してください。保存後にメニューからエアコンを選べます。")
        helpLabel.textColor = .secondaryLabelColor

        tokenField.placeholderString = "Bearerトークン"

        let saveButton = NSButton(title: "保存", target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"

        messageLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleLabel, helpLabel, tokenField, messageLabel, saveButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        tokenField.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            tokenField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            saveButton.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }

    @objc private func save() {
        let token = tokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            messageLabel.stringValue = "トークンを入力してください。"
            return
        }

        do {
            try store.saveToken(token)
            messageLabel.stringValue = "保存しました。"
            delegate?.preferencesDidSave()
        } catch {
            messageLabel.stringValue = error.localizedDescription
        }
    }
}
