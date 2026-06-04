import Foundation
import Security

/// Stores the OpenRouter API key locally without Keychain UI prompts (common for local Mac tools).
enum OpenRouterCredentialStore {
    private static let directoryName = "XYZT"
    private static let fileName = "openrouter-api-key"
    private static let fallbackDefaultsKey = "xyzt.openrouter.apiKey.fallback"

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }

    static func read() -> String? {
        if let fileValue = readFromFile() {
            KeychainMigration.deleteLegacyItem()
            return fileValue
        }
        if let legacy = KeychainMigration.readLegacyItem() {
            save(legacy)
            return legacy
        }
        if let fallback = UserDefaults.standard.string(forKey: fallbackDefaultsKey) {
            let trimmed = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    static func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            delete()
            return
        }
        do {
            try ensureDirectory()
            try Data(trimmed.utf8).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o600))],
                ofItemAtPath: fileURL.path
            )
            UserDefaults.standard.removeObject(forKey: fallbackDefaultsKey)
        } catch {
            UserDefaults.standard.set(trimmed, forKey: fallbackDefaultsKey)
        }
        KeychainMigration.deleteLegacyItem()
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
        UserDefaults.standard.removeObject(forKey: fallbackDefaultsKey)
        KeychainMigration.deleteLegacyItem()
    }

    private static func readFromFile() -> String? {
        guard let data = try? Data(contentsOf: fileURL),
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func ensureDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

// One-time migration from the old Keychain item that triggered login prompts on every run.
private enum KeychainMigration {
    private static let service = "xyzt.openrouter"
    private static let account = "api-key"

    static func readLegacyItem() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func deleteLegacyItem() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
