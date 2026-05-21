//
//  FenixuzEditedHistoryManager.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/EditedHistory/Sources/EditedMessageHistoryController.swift
//
//  iOS uses a TelegramCore message attribute (`EditedMessageHistoryAttribute`) that
//  is NOT present in the shared TelegramCore submodule consumed by Telegram-Mac
//  (the Mac submodule pins a different commit). Patching the upstream
//  TelegramCore submodule for one Fenixuz feature is high-risk for future pulls,
//  so this Mac port maintains its OWN per-message edit history store keyed by
//  (peerId, messageId) → [Entry].
//
//  Storage: UserDefaults(suiteName: "uz.fenixuz.app.editedHistory"), with the
//  per-key payload being a JSON blob of [{text, timestamp}]. Each entry is
//  recorded the first time we see a message edit for that (peer, msg) pair.
//
//  Consumer wiring (separate file `FenixuzEditedHistoryController.swift`):
//    - When the chat-message context menu builds for an edited message, push
//      FenixuzEditedHistoryController(messageId:peerId:) onto the navigation.
//    - The recorder (`record(text:peerId:messageId:timestamp:)`) is meant to be
//      called from the chat update pipeline when an edit notification fires.
//      For now, callers can opportunistically record edits whenever they have
//      both the old and new text in scope.

import Foundation
import Postbox
import TelegramCore

public struct FenixuzEditedHistoryEntry: Codable, Equatable {
    public let text: String
    public let timestamp: Int32

    public init(text: String, timestamp: Int32) {
        self.text = text
        self.timestamp = timestamp
    }
}

public final class FenixuzEditedHistoryManager {
    public static let shared = FenixuzEditedHistoryManager()

    private let defaults = UserDefaults(suiteName: "uz.fenixuz.app.editedHistory")
    private let lock = NSLock()

    private init() {}

    // MARK: - Public API

    public func entries(peerId: PeerId, messageId: Int32) -> [FenixuzEditedHistoryEntry] {
        lock.lock(); defer { lock.unlock() }
        return loadLocked(peerId: peerId, messageId: messageId)
    }

    /// Append a single entry. Idempotent for the (text + timestamp) pair —
    /// recording the same edit twice does not duplicate.
    public func record(text: String, peerId: PeerId, messageId: Int32, timestamp: Int32) {
        lock.lock(); defer { lock.unlock() }
        var existing = loadLocked(peerId: peerId, messageId: messageId)
        let entry = FenixuzEditedHistoryEntry(text: text, timestamp: timestamp)
        if existing.contains(entry) { return }
        existing.append(entry)
        // Cap at 50 entries per message to prevent unbounded growth.
        if existing.count > 50 {
            existing = Array(existing.suffix(50))
        }
        saveLocked(existing, peerId: peerId, messageId: messageId)
    }

    public func clear(peerId: PeerId, messageId: Int32) {
        lock.lock(); defer { lock.unlock() }
        defaults?.removeObject(forKey: key(peerId: peerId, messageId: messageId))
    }

    public func hasHistory(peerId: PeerId, messageId: Int32) -> Bool {
        return !entries(peerId: peerId, messageId: messageId).isEmpty
    }

    // MARK: - Storage helpers

    private func key(peerId: PeerId, messageId: Int32) -> String {
        return "msg_\(peerId.toInt64())_\(messageId)"
    }

    private func loadLocked(peerId: PeerId, messageId: Int32) -> [FenixuzEditedHistoryEntry] {
        guard let data = defaults?.data(forKey: key(peerId: peerId, messageId: messageId)) else {
            return []
        }
        return (try? JSONDecoder().decode([FenixuzEditedHistoryEntry].self, from: data)) ?? []
    }

    private func saveLocked(_ entries: [FenixuzEditedHistoryEntry], peerId: PeerId, messageId: Int32) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults?.set(data, forKey: key(peerId: peerId, messageId: messageId))
    }
}
