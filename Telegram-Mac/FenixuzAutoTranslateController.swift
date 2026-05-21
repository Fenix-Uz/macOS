//
//  FenixuzAutoTranslateController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ProMessager/Sources/FenixTranslateController.swift
//
//  Mac AppKit port. Auto-translate outgoing messages. The Mac side currently
//  only stores the user choice — the actual outgoing-translate consumer is
//  a future wave (the chat send pipeline needs hooking).
//
//  Storage (iOS parity):
//    UserDefaults(suiteName: "pro_messager")
//      "auto_translate_enabled" Bool   (default: false)
//      "auto_translate_lang"    String (default: "" — none chosen)
//      "auto_translate_downloaded" [String] (default: ["en","ru","uz"])

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import SwiftSignalKit

// MARK: - Storage

private let kATSuite        = "pro_messager"
private let kATEnabled      = "auto_translate_enabled"
private let kATLang         = "auto_translate_lang"
private let kATDownloaded   = "auto_translate_downloaded"

// MARK: - Language catalog (parity with iOS)

private struct ATLanguageOption: Equatable {
    let code: String
    let nameKey: String   // FenixuzL10n.autoTranslate_languageName(_:) key
}

private let autoTranslateLanguages: [ATLanguageOption] = [
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

private enum ATEntryId: Hashable {
    case section(Int)
    case info
    case toggle
    case header
    case language(String)
}

private enum ATEntry: Comparable, Identifiable {
    case section(Int)
    case info(Int, String)
    case toggle(Int, String, String, Bool, GeneralViewType)
    case header(Int, String)
    case language(Int, String /* code */, String /* display */, Bool /* selected */, Bool /* downloaded */, GeneralViewType)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return ATEntryId.section(id)
        case .info:            return ATEntryId.info
        case .toggle:          return ATEntryId.toggle
        case .header:          return ATEntryId.header
        case let .language(_, code, _, _, _, _): return ATEntryId.language(code)
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id):            return id * 1000
        case let .info(i, _):             return i
        case let .toggle(i, _, _, _, _):  return i
        case let .header(i, _):           return i
        case let .language(i, _, _, _, _, _): return i
        }
    }

    static func < (lhs: ATEntry, rhs: ATEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: ATEntry, rhs: ATEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.info(l1, l2), .info(r1, r2)): return l1 == r1 && l2 == r2
        case let (.toggle(l1, l2, l3, l4, l5), .toggle(r1, r2, r3, r4, r5)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5
        case let (.header(l1, l2), .header(r1, r2)): return l1 == r1 && l2 == r2
        case let (.language(l1, l2, l3, l4, l5, l6), .language(r1, r2, r3, r4, r5, r6)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5 && l6 == r6
        default: return false
        }
    }

    func item(_ arguments: ATArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        case let .info(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
        case let .toggle(_, title, subtitle, value, viewType):
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: title,
                description: subtitle,
                type: .switchable(value),
                viewType: viewType,
                action: {
                    arguments.updateEnabled(!value)
                }
            )
        case let .header(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
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
        }
    }
}

// MARK: - State + Arguments

private struct ATState: Equatable {
    var isEnabled: Bool
    var lang: String
    var downloaded: Set<String>

    static func load() -> ATState {
        let d = UserDefaults(suiteName: kATSuite)
        return ATState(
            isEnabled: d?.bool(forKey: kATEnabled) ?? false,
            lang:      d?.string(forKey: kATLang) ?? "",
            downloaded: Set(d?.stringArray(forKey: kATDownloaded) ?? ["en", "ru", "uz"])
        )
    }
}

private final class ATArguments {
    let updateEnabled: (Bool) -> Void
    let selectLang: (String) -> Void
    let downloadLang: (String) -> Void
    init(updateEnabled: @escaping (Bool) -> Void,
         selectLang: @escaping (String) -> Void,
         downloadLang: @escaping (String) -> Void) {
        self.updateEnabled = updateEnabled
        self.selectLang = selectLang
        self.downloadLang = downloadLang
    }
}

private func autoTranslateEntries(state: ATState, l10n: FenixuzL10n) -> [ATEntry] {
    var entries: [ATEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.info(next(), l10n.autoTranslate_info))

    entries.append(.section(2))
    entries.append(.toggle(next(),
                           l10n.autoTranslate_toggleTitle,
                           l10n.autoTranslate_toggleSubtitle,
                           state.isEnabled,
                           .singleItem))

    entries.append(.section(3))
    entries.append(.header(next(), l10n.autoTranslate_langHeader))

    let langs = autoTranslateLanguages
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
            state.lang == lang.code,
            state.downloaded.contains(lang.code),
            viewType
        ))
    }

    return entries
}

private func prepareAutoTranslateTransition(left: [AppearanceWrapperEntry<ATEntry>], right: [AppearanceWrapperEntry<ATEntry>], arguments: ATArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

class FenixuzAutoTranslateController: TableViewController {

    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(ATState.load(), ignoreRepeated: true)
    private let stateValue = Atomic(value: ATState.load())

    override var defaultBarTitle: String {
        return FenixuzL10n.current.autoTranslate_screenTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let updateState: ((inout ATState) -> Void) -> Void = { [weak self] mutate in
            guard let self = self else { return }
            let new = self.stateValue.modify { current in
                var s = current
                mutate(&s)
                return s
            }
            self.statePromise.set(new)
        }

        let defaults = UserDefaults(suiteName: kATSuite)

        let arguments = ATArguments(
            updateEnabled: { value in
                defaults?.set(value, forKey: kATEnabled)
                updateState { s in s.isEnabled = value }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            },
            selectLang: { code in
                defaults?.set(code, forKey: kATLang)
                updateState { s in s.lang = code }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            },
            downloadLang: { code in
                updateState { s in
                    s.downloaded.insert(code)
                    defaults?.set(Array(s.downloaded), forKey: kATDownloaded)
                }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<ATEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = autoTranslateEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareAutoTranslateTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
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
