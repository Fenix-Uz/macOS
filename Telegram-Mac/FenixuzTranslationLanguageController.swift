//
//  FenixuzTranslationLanguageController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ProMessager/Sources/FenixTranslationController.swift
//
//  Mac AppKit port. Single-select translation target-language list. Mirrors
//  iOS: uses a SECOND defaults suite "pro_messager_translation" with keys
//  "selected_language" + "downloaded_languages". (iOS uses a separate suite
//  here even though sibling controllers use "pro_messager"; we keep the
//  same suite split for byte-for-byte parity.)

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import SwiftSignalKit

private let kTLSuite       = "pro_messager_translation"
private let kTLSelected    = "selected_language"
private let kTLDownloaded  = "downloaded_languages"

// MARK: - Language catalog (parity with iOS)

private struct TLLanguageOption: Equatable {
    let code: String
    let nameKey: String
}

private let translationLanguages: [TLLanguageOption] = [
    .init(code: "en", nameKey: "en"),
    .init(code: "ru", nameKey: "ru"),
    .init(code: "uz", nameKey: "uz"),
    .init(code: "tr", nameKey: "tr"),
    .init(code: "de", nameKey: "de"),
    .init(code: "fr", nameKey: "fr"),
    .init(code: "es", nameKey: "es"),
    .init(code: "it", nameKey: "it"),
    .init(code: "ar", nameKey: "ar"),
    .init(code: "zh", nameKey: "zh"),
    .init(code: "ja", nameKey: "ja"),
    .init(code: "ko", nameKey: "ko"),
]

// MARK: - Entry

private enum TLEntryId: Hashable {
    case section(Int)
    case language(String)
    case footer
}

private enum TLEntry: Comparable, Identifiable {
    case section(Int)
    case language(Int, String, String, Bool, Bool, GeneralViewType)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return TLEntryId.section(id)
        case let .language(_, code, _, _, _, _): return TLEntryId.language(code)
        case .footer:          return TLEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id):                return id * 1000
        case let .language(i, _, _, _, _, _): return i
        case let .footer(i, _):               return i
        }
    }

    static func < (lhs: TLEntry, rhs: TLEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: TLEntry, rhs: TLEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.language(l1, l2, l3, l4, l5, l6), .language(r1, r2, r3, r4, r5, r6)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5 && l6 == r6
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: TLArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        case let .language(_, code, name, isSelected, isDownloaded, viewType):
            let label: String
            if isDownloaded {
                label = isSelected ? FenixuzL10n.current.autoTranslate_labelSelected : FenixuzL10n.current.autoTranslate_labelDownloaded
            } else {
                label = FenixuzL10n.current.autoTranslate_labelDownload
            }
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: name,
                type: .nextContext(label),
                viewType: viewType,
                action: {
                    if isDownloaded {
                        arguments.selectLang(code)
                    } else {
                        arguments.downloadLang(code)
                    }
                }
            )
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

// MARK: - State + Arguments

private struct TLState: Equatable {
    var selected: String
    var downloaded: Set<String>

    static func load() -> TLState {
        let d = UserDefaults(suiteName: kTLSuite)
        return TLState(
            selected:   d?.string(forKey: kTLSelected) ?? "en",
            downloaded: Set(d?.stringArray(forKey: kTLDownloaded) ?? ["en", "ru", "uz"])
        )
    }
}

private final class TLArguments {
    let selectLang: (String) -> Void
    let downloadLang: (String) -> Void
    init(selectLang: @escaping (String) -> Void,
         downloadLang: @escaping (String) -> Void) {
        self.selectLang = selectLang
        self.downloadLang = downloadLang
    }
}

private func translationLanguageEntries(state: TLState, l10n: FenixuzL10n) -> [TLEntry] {
    var entries: [TLEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))

    let langs = translationLanguages
    for (i, lang) in langs.enumerated() {
        let viewType: GeneralViewType
        if langs.count == 1 { viewType = .singleItem }
        else if i == 0 { viewType = .firstItem }
        else if i == langs.count - 1 { viewType = .lastItem }
        else { viewType = .innerItem }
        entries.append(.language(
            next(),
            lang.code,
            l10n.autoTranslate_languageName(lang.nameKey),
            state.selected == lang.code,
            state.downloaded.contains(lang.code),
            viewType
        ))
    }

    entries.append(.section(2))
    entries.append(.footer(next(), l10n.translationLang_footer))

    return entries
}

private func prepareTLTransition(left: [AppearanceWrapperEntry<TLEntry>], right: [AppearanceWrapperEntry<TLEntry>], arguments: TLArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

class FenixuzTranslationLanguageController: TableViewController {

    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(TLState.load(), ignoreRepeated: true)
    private let stateValue = Atomic(value: TLState.load())

    override var defaultBarTitle: String {
        return FenixuzL10n.current.translationLang_screenTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let updateState: ((inout TLState) -> Void) -> Void = { [weak self] mutate in
            guard let self = self else { return }
            let new = self.stateValue.modify { current in
                var s = current
                mutate(&s)
                return s
            }
            self.statePromise.set(new)
        }

        let defaults = UserDefaults(suiteName: kTLSuite)

        let arguments = TLArguments(
            selectLang: { code in
                defaults?.set(code, forKey: kTLSelected)
                updateState { s in s.selected = code }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            },
            downloadLang: { code in
                updateState { s in
                    s.downloaded.insert(code)
                    defaults?.set(Array(s.downloaded), forKey: kTLDownloaded)
                }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<TLEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = translationLanguageEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareTLTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
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
