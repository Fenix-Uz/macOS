//
//  FenixuzTextStyleController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ProMessager/Sources/FenixTextStyleController.swift
//
//  Mac AppKit port. Single-select list of text styles. Mirrors iOS:
//    - UserDefaults(suiteName: "pro_messager")["text_style"] = "<style>"
//    - Posts FenixSettingsChanged notification on change.
//
//  iOS uses ItemListController + ItemListDisclosureItem with badge label;
//  Mac uses TableViewController + GeneralInteractedRowItem with .nextContext
//  (the right-side detail text) showing "✓ Tanlangan" / "Selected" on the
//  current row.

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import SwiftSignalKit

// MARK: - Text style enum (parity with iOS FenixTextStyle)

public enum FenixuzTextStyle: String, CaseIterable {
    case none           = "none"
    case bold           = "bold"
    case italic         = "italic"
    case monospace      = "monospace"
    case strikethrough  = "strikethrough"
    case underline      = "underline"
    case spoiler        = "spoiler"

    public static var current: FenixuzTextStyle {
        let raw = UserDefaults(suiteName: "pro_messager")?.string(forKey: "text_style") ?? "none"
        return FenixuzTextStyle(rawValue: raw) ?? .none
    }
}

// MARK: - Entry

private enum TextStyleEntryId: Hashable {
    case section(Int)
    case header
    case style(String)
    case footer
}

private enum TextStyleEntry: Comparable, Identifiable {
    case section(Int)
    case header(Int, String)
    case style(Int, FenixuzTextStyle, String, Bool, GeneralViewType)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return TextStyleEntryId.section(id)
        case .header:          return TextStyleEntryId.header
        case let .style(_, s, _, _, _): return TextStyleEntryId.style(s.rawValue)
        case .footer:          return TextStyleEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id):  return id * 1000
        case let .header(i, _): return i
        case let .style(i, _, _, _, _): return i
        case let .footer(i, _): return i
        }
    }

    static func < (lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: TextStyleEntry, rhs: TextStyleEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.header(l1, l2), .header(r1, r2)): return l1 == r1 && l2 == r2
        case let (.style(l1, l2, l3, l4, l5), .style(r1, r2, r3, r4, r5)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: TextStyleArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        case let .header(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
        case let .style(_, style, name, isSelected, viewType):
            let label = isSelected ? FenixuzL10n.current.textStyle_selectedLabel : ""
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: name,
                type: .nextContext(label),
                viewType: viewType,
                action: {
                    arguments.selectStyle(style)
                }
            )
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

// MARK: - State + Arguments

private struct TextStyleState: Equatable {
    var selectedStyle: FenixuzTextStyle

    static func load() -> TextStyleState {
        return TextStyleState(selectedStyle: FenixuzTextStyle.current)
    }
}

private final class TextStyleArguments {
    let selectStyle: (FenixuzTextStyle) -> Void
    init(selectStyle: @escaping (FenixuzTextStyle) -> Void) {
        self.selectStyle = selectStyle
    }
}

// MARK: - Entries builder

private func textStyleEntries(state: TextStyleState, l10n: FenixuzL10n) -> [TextStyleEntry] {
    var entries: [TextStyleEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.header(next(), l10n.textStyle_listHeader))

    let all = FenixuzTextStyle.allCases
    for (i, style) in all.enumerated() {
        let isSelected = state.selectedStyle == style
        let viewType: GeneralViewType
        if all.count == 1 { viewType = .singleItem }
        else if i == 0 { viewType = .firstItem }
        else if i == all.count - 1 { viewType = .lastItem }
        else { viewType = .innerItem }
        entries.append(.style(next(), style, l10n.textStyle_displayName(style.rawValue), isSelected, viewType))
    }

    entries.append(.section(2))
    entries.append(.footer(next(), l10n.textStyle_footer))

    return entries
}

private func prepareTextStyleTransition(left: [AppearanceWrapperEntry<TextStyleEntry>], right: [AppearanceWrapperEntry<TextStyleEntry>], arguments: TextStyleArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

class FenixuzTextStyleController: TableViewController {

    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(TextStyleState.load(), ignoreRepeated: true)
    private let stateValue = Atomic(value: TextStyleState.load())

    override var defaultBarTitle: String {
        return FenixuzL10n.current.textStyle_screenTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let updateState: ((inout TextStyleState) -> Void) -> Void = { [weak self] mutate in
            guard let self = self else { return }
            let new = self.stateValue.modify { current in
                var s = current
                mutate(&s)
                return s
            }
            self.statePromise.set(new)
        }

        let defaults = UserDefaults(suiteName: "pro_messager")

        let arguments = TextStyleArguments(selectStyle: { style in
            defaults?.set(style.rawValue, forKey: "text_style")
            updateState { state in
                state.selectedStyle = style
            }
            NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
        })

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<TextStyleEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = textStyleEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareTextStyleTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
            }
            |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
    }

    deinit {
        disposable.dispose()
    }
}
