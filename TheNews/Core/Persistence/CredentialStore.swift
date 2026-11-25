import Foundation
import Security

nonisolated protocol CredentialStoring: Sendable {
    func load() -> APIKey?
    func save(_ credential: APIKey) throws(CredentialStoreError)
    func delete() throws(CredentialStoreError)
}

nonisolated enum CredentialStoreError: Error, Equatable, Sendable {
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

/// Stores the NewsAPI key in the Keychain (never in UserDefaults).
nonisolated struct KeychainCredentialStore: CredentialStoring {
    private let service: String
    private let account: String

    init(service: String = "com.alihaidar.TheNews", account: String = "newsapi-key") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> APIKey? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return APIKey(raw)
    }

    func save(_ credential: APIKey) throws(CredentialStoreError) {
        guard let data = credential.value.data(using: .utf8) else { throw .encodingFailed }
        try delete()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw .unexpectedStatus(status) }
    }

    func delete() throws(CredentialStoreError) {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .unexpectedStatus(status)
        }
    }
}
