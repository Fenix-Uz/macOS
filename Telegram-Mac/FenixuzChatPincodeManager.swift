//
//  FenixuzChatPincodeManager.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ChatLock/Sources/ChatPincodeManager.swift
//
//  Per-chat pincode'ni Keychain'da saqlaydi (`uz.fenixuz.app.ChatLock` service
//  identifier ostida). Eski UserDefaults-based plaintext storage Wave 1 (iOS)
//  da bekor qilingan; Mac uchun yangi orniftiqliq holatdan boshlanadi.
//
//  Bu modul faqat DATA layer — UI (pin entry view, lock state monitor) Wave 5
//  da AppKit ostida yoziladi. Hozircha Mac consumer'lar hech qanday joydan
//  bu manager'ni chaqirmaydi; ammo siyosatga ko'ra modul mavjud bo'lib turadi,
//  shunda kelajakda biror joy locked chat'ga kirmoqchi bo'lsa, `getPincode`,
//  `setPincode`, `removePincode`, `verify` API'lari tayyor.
//
//  Constant-time compare timing side-channel'larga qarshi.

import Foundation
import Security
import Postbox

private let keychainService = "uz.fenixuz.app.ChatLock"

public final class FenixuzChatPincodeManager {
    public static let shared = FenixuzChatPincodeManager()

    private init() {}

    // MARK: - Public API

    public func getPincode(for peerId: PeerId) -> String? {
        return read(account: account(for: peerId))
    }

    public func setPincode(_ code: String, for peerId: PeerId) {
        write(code, account: account(for: peerId))
    }

    public func removePincode(for peerId: PeerId) {
        delete(account: account(for: peerId))
    }

    public func isLocked(_ peerId: PeerId) -> Bool {
        return read(account: account(for: peerId)) != nil
    }

    public func verify(_ code: String, for peerId: PeerId) -> Bool {
        guard let stored = read(account: account(for: peerId)) else { return false }
        return constantTimeEquals(stored, code)
    }

    // MARK: - Keychain plumbing

    private func account(for peerId: PeerId) -> String {
        return "\(peerId.toInt64())"
    }

    private func baseQuery(account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func write(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let updateQuery = baseQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var addQuery = baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        _ = SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func delete(account: String) {
        let query = baseQuery(account: account)
        _ = SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Constant-time compare

private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)
    if aBytes.count != bBytes.count {
        return false
    }
    var diff: UInt8 = 0
    for i in 0..<aBytes.count {
        diff |= aBytes[i] ^ bBytes[i]
    }
    return diff == 0
}
