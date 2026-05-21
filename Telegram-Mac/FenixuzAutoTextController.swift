//
//  FenixuzAutoTextController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/ProMessager/Sources/FenixAutoTextController.swift
//
//  Mac AppKit port. "Auto-text" feature: when enabled, an opt-in suffix is
//  appended to every outgoing message.
//
//  Storage (parity with iOS):
//    UserDefaults(suiteName: "pro_messager")
//      "auto_text_enabled"  Bool   (default: false)
//      "auto_text_content"  String (default: "")
//
//  Posts FenixSettingsChanged notification when either field changes so the
//  Mac chat-input consumer (future wave) can re-read.

import Cocoa
import TGUIKit
import TelegramCore
import Localization
import SwiftSignalKit

// MARK: - Storage

private let kAutoTextSuite     = "pro_messager"
private let kAutoTextEnabled   = "auto_text_enabled"
private let kAutoTextContent   = "auto_text_content"

// MARK: - Entry

private enum AutoTextEntryId: Hashable {
    case section(Int)
    case info
    case toggle
    case inputHeader
    case input
    case inputHint
}

private enum AutoTextEntry: Comparable, Identifiable {
    case section(Int)
    case info(Int, String)
    case toggle(Int, String, String, Bool, GeneralViewType)
    case inputHeader(Int, String)
    case input(Int, String /* placeholder */, String /* current value */, GeneralViewType)
    case inputHint(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return AutoTextEntryId.section(id)
        case .info:            return AutoTextEntryId.info
        case .toggle:          return AutoTextEntryId.toggle
        case .inputHeader:     return AutoTextEntryId.inputHeader
        case .input:           return AutoTextEntryId.input
        case .inputHint:       return AutoTextEntryId.inputHint
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id):              return id * 1000
        case let .info(i, _):               return i
        case let .toggle(i, _, _, _, _):    return i
        case let .inputHeader(i, _):        return i
        case let .input(i, _, _, _):        return i
        case let .inputHint(i, _):          return i
        }
    }

    static func < (lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: AutoTextEntry, rhs: AutoTextEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.info(l1, l2), .info(r1, r2)): return l1 == r1 && l2 == r2
        case let (.toggle(l1, l2, l3, l4, l5), .toggle(r1, r2, r3, r4, r5)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5
        case let (.inputHeader(l1, l2), .inputHeader(r1, r2)): return l1 == r1 && l2 == r2
        case let (.input(l1, l2, l3, l4), .input(r1, r2, r3, r4)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4
        case let (.inputHint(l1, l2), .inputHint(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: AutoTextArguments, initialSize: NSSize) -> TableRowItem {
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
        case let .inputHeader(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
        case let .input(_, placeholder, value, _):
            return GeneralInputRowItem(
                initialSize,
                stableId: stableId,
                placeholder: placeholder,
                text: value,
                limit: 300,
                textChangeHandler: { newValue in
                    arguments.updateContent(newValue)
                },
                holdText: true,
                automaticallyBecomeResponder: false
            )
        case let .inputHint(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

// MARK: - State + Arguments

private struct AutoTextState: Equatable {
    var isEnabled: Bool
    var content: String

    static func load() -> AutoTextState {
        let d = UserDefaults(suiteName: kAutoTextSuite)
        return AutoTextState(
            isEnabled: d?.bool(forKey: kAutoTextEnabled) ?? false,
            content:   d?.string(forKey: kAutoTextContent) ?? ""
        )
    }
}

private final class AutoTextArguments {
    let updateEnabled: (Bool) -> Void
    let updateContent: (String) -> Void
    init(updateEnabled: @escaping (Bool) -> Void,
         updateContent: @escaping (String) -> Void) {
        self.updateEnabled = updateEnabled
        self.updateContent = updateContent
    }
}

private func autoTextEntries(state: AutoTextState, l10n: FenixuzL10n) -> [AutoTextEntry] {
    var entries: [AutoTextEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.info(next(), l10n.autoText_info))

    entries.append(.section(2))
    entries.append(.toggle(next(),
                           l10n.autoText_toggleTitle,
                           l10n.autoText_toggleSubtitle,
                           state.isEnabled,
                           .singleItem))

    entries.append(.section(3))
    entries.append(.inputHeader(next(), l10n.autoText_inputHeader))
    entries.append(.input(next(), l10n.autoText_inputPlaceholder, state.content, .singleItem))
    entries.append(.inputHint(next(), l10n.autoText_inputHint))

    return entries
}

private func prepareAutoTextTransition(left: [AppearanceWrapperEntry<AutoTextEntry>], right: [AppearanceWrapperEntry<AutoTextEntry>], arguments: AutoTextArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

class FenixuzAutoTextController: TableViewController {

    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(AutoTextState.load(), ignoreRepeated: true)
    private let stateValue = Atomic(value: AutoTextState.load())

    override var defaultBarTitle: String {
        return FenixuzL10n.current.autoText_screenTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let updateState: ((inout AutoTextState) -> Void) -> Void = { [weak self] mutate in
            guard let self = self else { return }
            let new = self.stateValue.modify { current in
                var s = current
                mutate(&s)
                return s
            }
            self.statePromise.set(new)
        }

        let defaults = UserDefaults(suiteName: kAutoTextSuite)

        let arguments = AutoTextArguments(
            updateEnabled: { value in
                defaults?.set(value, forKey: kAutoTextEnabled)
                updateState { s in s.isEnabled = value }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            },
            updateContent: { text in
                defaults?.set(text, forKey: kAutoTextContent)
                updateState { s in s.content = text }
                NotificationCenter.default.post(name: NSNotification.Name("FenixSettingsChanged"), object: nil)
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<AutoTextEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = autoTextEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareAutoTextTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
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
