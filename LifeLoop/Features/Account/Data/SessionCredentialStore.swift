import Foundation
import Security

struct SessionCredential: Codable {
    let token: String
    let expiresAt: Date
    var account: Account? = nil
}

@MainActor
protocol SessionCredentialStore {
    func read() throws -> SessionCredential?
    func save(_ credential: SessionCredential) throws
    func clear() throws
}

/// Each server gets a separate Keychain entry. Passwords are never stored.
final class KeychainSessionCredentialStore: SessionCredentialStore {
    private let service: String

    init(server: URL) {
        service = "com.personal.LifeLoop.session.\(server.absoluteString)"
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "session"]
    }

    func read() throws -> SessionCredential? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw StorageError.operationFailed(status)
        }
        return try JSONDecoder().decode(SessionCredential.self, from: data)
    }

    func save(_ credential: SessionCredential) throws {
        let data = try JSONEncoder().encode(credential)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageError.operationFailed(status) }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.operationFailed(status)
        }
    }

    enum StorageError: Error { case operationFailed(OSStatus) }
}
