import Foundation
import Security

public enum CredentialStoreError: Error, Equatable, Sendable {
    case invalidCredential
    case unavailable
    case denied
    case keychainFailure(OSStatus)
}

extension CredentialStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCredential: "The credential cannot be empty."
        case .unavailable: "No credential is stored for this account."
        case .denied: "Keychain access was denied."
        case .keychainFailure: "Keychain could not complete the credential operation."
        }
    }
}

/// Stores provider credentials separately from the project database and export data.
public actor KeychainCredentialStore {
    public static let defaultService = "com.projectos.credentials"

    private let service: String

    public init(service: String = KeychainCredentialStore.defaultService) {
        self.service = service
    }

    public func save(_ credential: String, account: String) throws {
        guard !credential.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !account.isEmpty,
              let data = credential.data(using: .utf8) else {
            throw CredentialStoreError.invalidCredential
        }

        let lookup = baseQuery(account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(lookup as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw map(updateStatus) }

        var insertion = lookup
        insertion[kSecValueData] = data
        insertion[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw map(addStatus) }
    }

    public func credential(account: String) throws -> String {
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw map(status) }
        guard let data = result as? Data,
              let credential = String(data: data, encoding: .utf8),
              !credential.isEmpty else {
            throw CredentialStoreError.unavailable
        }
        return credential
    }

    public func containsCredential(account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData] = false
        query[kSecMatchLimit] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw map(status) }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanFalse as Any
        ]
    }

    private func map(_ status: OSStatus) -> CredentialStoreError {
        switch status {
        case errSecItemNotFound: .unavailable
        case errSecAuthFailed, errSecInteractionNotAllowed, errSecUserCanceled: .denied
        default: .keychainFailure(status)
        }
    }
}
