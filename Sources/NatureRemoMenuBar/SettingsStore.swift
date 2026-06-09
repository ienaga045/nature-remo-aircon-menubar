import Foundation
import Security

final class SettingsStore {
    private let service = "NatureRemoMenuBar"
    private let tokenAccount = "cloud-api-token"
    private let applianceKey = "selectedApplianceID"
    private let deviceKey = "selectedDeviceID"
    private let lastTemperaturesKey = "lastTemperaturesByApplianceID"

    var selectedApplianceID: String? {
        get { UserDefaults.standard.string(forKey: applianceKey) }
        set { UserDefaults.standard.set(newValue, forKey: applianceKey) }
    }

    var selectedDeviceID: String? {
        get { UserDefaults.standard.string(forKey: deviceKey) }
        set { UserDefaults.standard.set(newValue, forKey: deviceKey) }
    }

    func lastTemperature(for applianceID: String) -> String? {
        let temperatures = UserDefaults.standard.dictionary(forKey: lastTemperaturesKey) as? [String: String]
        return temperatures?[applianceID]
    }

    func saveLastTemperature(_ temperature: String, for applianceID: String) {
        var temperatures = UserDefaults.standard.dictionary(forKey: lastTemperaturesKey) as? [String: String] ?? [:]
        temperatures[applianceID] = temperature
        UserDefaults.standard.set(temperatures, forKey: lastTemperaturesKey)
    }

    func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError(status: addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError(status: status)
        }
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        "Keychain保存エラー: \(status)"
    }
}
