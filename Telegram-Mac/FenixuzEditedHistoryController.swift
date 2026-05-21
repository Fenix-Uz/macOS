//
//  FenixuzEditedHistoryController.swift
//  Telegram-Mac
//
//  Viewer for the Fenixuz-local edited-message history (stored by
//  FenixuzEditedHistoryManager). Simple chronological list — newest edits
//  first, plus the current message text as the topmost entry.
//
//  Mac AppKit port. Use as a TableViewController in the chat info / context
//  menu flow: call `presentEditedHistory(for:in:peerId:messageId:currentText:)`
//  from the consumer.

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit

// MARK: - Entry

private enum EHEntryId: Hashable {
    case section(Int)
    case header
    case entry(Int)
    case footer
}

private enum EHEntry: Comparable, Identifiable {
    case section(Int)
    case header(Int, String)
    case entry(Int, String /* date */, String /* text */, Bool /* isCurrent */)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return EHEntryId.section(id)
        case .header:          return EHEntryId.header
        case let .entry(i, _, _, _): return EHEntryId.entry(i)
        case .footer:          return EHEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id): return id * 1000
        case let .header(i, _): return i
        case let .entry(i, _, _, _): return i
        case let .footer(i, _): return i
        }
    }

    static func < (lhs: EHEntry, rhs: EHEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: EHEntry, rhs: EHEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.header(l1, l2), .header(r1, r2)): return l1 == r1 && l2 == r2
        case let (.entry(l1, l2, l3, l4), .entry(r1, r2, r3, r4)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 16, stableId: stableId, viewType: .separator)
        case let .header(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
        case let .entry(_, date, text, isCurrent):
            let prefix = isCurrent ? FenixuzL10n.current.editedHistory_currentLabel + ": " : ""
            return GeneralInteractedRowItem(
                initialSize,
                stableId: stableId,
                name: prefix + text,
                description: date,
                type: .none,
                viewType: .singleItem,
                action: {}
            )
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

private func editedHistoryEntries(currentText: String, history: [FenixuzEditedHistoryEntry], l10n: FenixuzL10n) -> [EHEntry] {
    var entries: [EHEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.header(next(), l10n.editedHistory_listHeader))

    // Latest first — current text, then history newest-to-oldest.
    let now = Int32(Date().timeIntervalSince1970)
    let nowDate = stringForTimestamp(now)
    entries.append(.entry(next(), nowDate, currentText, true))

    let sorted = history.sorted(by: { $0.timestamp > $1.timestamp })
    for h in sorted {
        entries.append(.section(idx + 1000))
        entries.append(.entry(next(), stringForTimestamp(h.timestamp), h.text, false))
    }

    if history.isEmpty {
        entries.append(.section(99))
        entries.append(.footer(next(), l10n.editedHistory_empty))
    } else {
        entries.append(.section(99))
        entries.append(.footer(next(), l10n.editedHistory_footer))
    }

    return entries
}

private func stringForTimestamp(_ ts: Int32) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(ts))
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f.string(from: date)
}

private func prepareEditedHistoryTransition(left: [AppearanceWrapperEntry<EHEntry>], right: [AppearanceWrapperEntry<EHEntry>], initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

final class FenixuzEditedHistoryController: TableViewController {

    private let peerId: PeerId
    private let messageId: Int32
    private let currentText: String

    override var defaultBarTitle: String {
        return FenixuzL10n.current.editedHistory_screenTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    init(context: AccountContext, peerId: PeerId, messageId: Int32, currentText: String) {
        self.peerId = peerId
        self.messageId = messageId
        self.currentText = currentText
        super.init(context)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<EHEntry>]>(value: [])

        let history = FenixuzEditedHistoryManager.shared.entries(peerId: peerId, messageId: messageId)
        let l10n = FenixuzL10n.current
        let entries = editedHistoryEntries(currentText: currentText, history: history, l10n: l10n)
            .map { AppearanceWrapperEntry(entry: $0, appearance: appAppearance) }
        let previous = previousEntries.swap(entries)
        let transition = prepareEditedHistoryTransition(left: previous, right: entries, initialSize: initialSize.modify { $0 })
        self.genericView.merge(with: transition)
        self.readyOnce()
    }
}

// MARK: - Public helper

enum FenixuzEditedHistory {
    /// Push the viewer onto the given navigation controller.
    static func push(navigation: NavigationViewController?,
                     context: AccountContext,
                     peerId: PeerId,
                     messageId: Int32,
                     currentText: String) {
        let controller = FenixuzEditedHistoryController(context: context, peerId: peerId, messageId: messageId, currentText: currentText)
        navigation?.push(controller)
    }
}
