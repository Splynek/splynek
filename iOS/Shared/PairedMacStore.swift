// Copyright © 2026 Splynek. MIT.
//
// PairedMacStore — App-Group-shared persistence for the paired-Mac
// list.  Both the main companion app and the Share Extension read +
// write here, so they MUST agree on the storage location.
//
// We split the data into two layers:
//
//  1. Plist with metadata (uuid / displayName / lastKnownHost /
//     lastKnownPort / lastSeen) — stored in the App Group's shared
//     `UserDefaults`.  Cheap to read on extension launch.
//
//  2. Keychain item per Mac, holding the authentication token.  Keyed
//     on `uuid`, kSecAttrAccessGroup matches the App Group.  This is
//     where the actual secret lives.
//
// Storing the token outside the keychain is a privacy / security bug
// — share-extension Info.plist is world-readable on a backed-up
// device, but keychain items are device-bound (with appropriate
// kSecAttrAccessibleWhenUnlocked attribute).
//
// API is synchronous because both consumers (a SwiftUI view + an
// extension's `loadView`) need it on the main queue.  The keychain
// calls are fast (<1ms) so this is fine.

import Foundation
#if canImport(Security)
import Security
#endif

public final class PairedMacStore {
    // MARK: Constants

    /// App Group identifier shared by the app + Share Extension.
    /// Must match the entitlements file.
    public static let appGroupID = "group.app.splynek.companion"
    private static let plistKey = "splynek.companion.pairedMacs"
    private static let keychainService = "app.splynek.companion.token"

    // MARK: Init

    private let defaults: UserDefaults

    public init?(suiteName: String = PairedMacStore.appGroupID) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    /// In-memory store for tests — bypasses the keychain entirely.
    public static func inMemory() -> PairedMacStore {
        PairedMacStore(memoryOnly: true)
    }

    private var memoryMode: Bool = false
    private var memoryRecords: [String: PairedMac] = [:]
    private init(memoryOnly: Bool) {
        self.memoryMode = memoryOnly
        self.defaults = UserDefaults(suiteName: "splynek.test.\(UUID().uuidString)")
            ?? UserDefaults.standard
    }

    // MARK: Read

    /// Returns all known paired Macs.  Tokens are filled in from the
    /// keychain.  If the keychain item is missing for a given uuid the
    /// returned `PairedMac.token` is empty — callers should treat that
    /// as "needs re-pairing" and not attempt requests.
    public func all() -> [PairedMac] {
        if memoryMode { return Array(memoryRecords.values).sorted { $0.displayName < $1.displayName } }
        guard let data = defaults.data(forKey: Self.plistKey) else { return [] }
        guard var records = try? PropertyListDecoder().decode([PairedMac].self, from: data) else {
            return []
        }
        for i in records.indices {
            records[i].token = (try? readToken(uuid: records[i].uuid)) ?? ""
        }
        return records.sorted { $0.displayName < $1.displayName }
    }

    public func get(uuid: String) -> PairedMac? {
        all().first(where: { $0.uuid == uuid })
    }

    // MARK: Write

    /// Insert / update a paired Mac.  The token is moved to the
    /// keychain; the on-disk plist holds an empty string in its place.
    @discardableResult
    public func upsert(_ mac: PairedMac) -> Bool {
        if memoryMode { memoryRecords[mac.uuid] = mac; return true }
        var redacted = mac
        let token = mac.token
        redacted.token = ""
        var existing = (try? loadPlist()) ?? []
        existing.removeAll { $0.uuid == mac.uuid }
        existing.append(redacted)
        do {
            try writeToken(uuid: mac.uuid, token: token)
            try savePlist(existing)
            return true
        } catch {
            return false
        }
    }

    public func remove(uuid: String) {
        if memoryMode { memoryRecords.removeValue(forKey: uuid); return }
        var existing = (try? loadPlist()) ?? []
        existing.removeAll { $0.uuid == uuid }
        try? savePlist(existing)
        try? deleteToken(uuid: uuid)
    }

    // MARK: Plist persistence

    private func loadPlist() throws -> [PairedMac] {
        guard let data = defaults.data(forKey: Self.plistKey) else { return [] }
        return try PropertyListDecoder().decode([PairedMac].self, from: data)
    }

    private func savePlist(_ records: [PairedMac]) throws {
        let data = try PropertyListEncoder().encode(records)
        defaults.set(data, forKey: Self.plistKey)
    }

    // MARK: Keychain

    private func readToken(uuid: String) throws -> String {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      uuid,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        if !memoryMode {
            query[kSecAttrAccessGroup as String] = Self.appGroupID
        }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return "" }
        if status != errSecSuccess {
            throw NSError(domain: "PairedMacStore.keychain", code: Int(status))
        }
        guard let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
            return ""
        }
        return str
        #else
        return ""
        #endif
    }

    private func writeToken(uuid: String, token: String) throws {
        #if canImport(Security)
        let data = Data(token.utf8)
        var query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      uuid,
        ]
        if !memoryMode {
            query[kSecAttrAccessGroup as String] = Self.appGroupID
        }
        let attrs: [String: Any] = [
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
        ]
        // Try update first, then add.
        let updStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery.merge(attrs) { _, b in b }
            let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw NSError(domain: "PairedMacStore.keychain", code: Int(addStatus))
            }
        } else if updStatus != errSecSuccess {
            throw NSError(domain: "PairedMacStore.keychain", code: Int(updStatus))
        }
        #endif
    }

    private func deleteToken(uuid: String) throws {
        #if canImport(Security)
        var query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      Self.keychainService,
            kSecAttrAccount as String:      uuid,
        ]
        if !memoryMode {
            query[kSecAttrAccessGroup as String] = Self.appGroupID
        }
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: "PairedMacStore.keychain", code: Int(status))
        }
        #endif
    }
}
