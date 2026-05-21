//
//  FenixuzTasksController.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/Tasks/Sources/TasksTabController.swift
//                + TodoListController + TodoItemController
//
//  Mac AppKit port. iOS uses 3 sequential controllers (tab → folder list →
//  task list → task detail). Mac collapses the first two into a single
//  TableViewController showing folders inline; tapping a folder opens a
//  task list child controller; tapping a task opens a detail editor.
//
//  Storage: FenixuzTasksDatabase (SQLite).

import Cocoa
import TGUIKit
import SwiftSignalKit
import Localization

// MARK: - Entry

private enum TasksEntryId: Hashable {
    case section(Int)
    case header
    case folder(String)
    case addFolder
    case footer
}

private enum TasksEntry: Comparable, Identifiable {
    case section(Int)
    case header(Int, String)
    case folder(Int, String /* id */, String /* title */, Int /* done */, Int /* total */, GeneralViewType)
    case addFolder(Int, GeneralViewType)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return TasksEntryId.section(id)
        case .header:          return TasksEntryId.header
        case let .folder(_, id, _, _, _, _): return TasksEntryId.folder(id)
        case .addFolder:       return TasksEntryId.addFolder
        case .footer:          return TasksEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id): return id * 1000
        case let .header(i, _): return i
        case let .folder(i, _, _, _, _, _): return i
        case let .addFolder(i, _): return i
        case let .footer(i, _): return i
        }
    }

    static func < (lhs: TasksEntry, rhs: TasksEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: TasksEntry, rhs: TasksEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.header(l1, l2), .header(r1, r2)): return l1 == r1 && l2 == r2
        case let (.folder(l1, l2, l3, l4, l5, l6), .folder(r1, r2, r3, r4, r5, r6)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4 && l5 == r5 && l6 == r6
        case let (.addFolder(l1, l2), .addFolder(r1, r2)): return l1 == r1 && l2 == r2
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: TasksArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId, viewType: .separator)
        case let .header(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textTopItem)
        case let .folder(_, id, title, done, total, viewType):
            let progress = total > 0 ? "\(done)/\(total)" : "—"
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: title,
                description: progress,
                type: .next,
                viewType: viewType,
                action: { arguments.openFolder(id) }
            )
        case let .addFolder(_, viewType):
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: FenixuzL10n.current.tasks_addFolder,
                type: .none,
                viewType: viewType,
                action: { arguments.addFolderPrompt() }
            )
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

private struct TasksState: Equatable {
    var folders: [FenixuzTodoFolder]
    var counts: [String: (done: Int, total: Int)]

    static func == (lhs: TasksState, rhs: TasksState) -> Bool {
        guard lhs.folders == rhs.folders else { return false }
        if lhs.counts.count != rhs.counts.count { return false }
        for (k, v) in lhs.counts {
            guard let r = rhs.counts[k], r.done == v.done, r.total == v.total else { return false }
        }
        return true
    }
}

private final class TasksArguments {
    let openFolder: (String) -> Void
    let addFolderPrompt: () -> Void
    init(openFolder: @escaping (String) -> Void,
         addFolderPrompt: @escaping () -> Void) {
        self.openFolder = openFolder
        self.addFolderPrompt = addFolderPrompt
    }
}

private func tasksEntries(state: TasksState, l10n: FenixuzL10n) -> [TasksEntry] {
    var entries: [TasksEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.header(next(), l10n.tasks_folderHeader))

    let folders = state.folders
    if folders.isEmpty {
        entries.append(.addFolder(next(), .singleItem))
    } else {
        for (i, folder) in folders.enumerated() {
            let viewType: GeneralViewType
            if folders.count == 1 { viewType = .firstItem }
            else if i == 0 { viewType = .firstItem }
            else if i == folders.count - 1 { viewType = .innerItem }
            else { viewType = .innerItem }
            let c = state.counts[folder.id] ?? (0, 0)
            entries.append(.folder(next(), folder.id, folder.title, c.done, c.total, viewType))
        }
        entries.append(.addFolder(next(), .lastItem))
    }

    entries.append(.section(99))
    entries.append(.footer(next(), l10n.tasks_footer))

    return entries
}

private func prepareTasksTransition(left: [AppearanceWrapperEntry<TasksEntry>], right: [AppearanceWrapperEntry<TasksEntry>], arguments: TasksArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

// MARK: - Controller

class FenixuzTasksController: TableViewController {

    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(TasksState(folders: [], counts: [:]), ignoreRepeated: true)
    private let stateValue = Atomic(value: TasksState(folders: [], counts: [:]))

    override var defaultBarTitle: String {
        return FenixuzL10n.current.tab_tasks
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let window = context.window

        let reload: () -> Void = { [weak self] in
            guard let self = self else { return }
            let folders = FenixuzTasksDatabase.shared.loadFolders()
            var counts: [String: (Int, Int)] = [:]
            for f in folders {
                counts[f.id] = FenixuzTasksDatabase.shared.countActiveAndTotal(folderId: f.id)
            }
            let next = self.stateValue.modify { _ in TasksState(folders: folders, counts: counts) }
            self.statePromise.set(next)
        }

        let arguments = TasksArguments(
            openFolder: { [weak self] folderId in
                guard let self = self else { return }
                let folder = FenixuzTasksDatabase.shared.loadFolders().first(where: { $0.id == folderId })
                if let folder = folder {
                    self.navigationController?.push(FenixuzTaskListController(context: self.context, folder: folder, onChange: reload))
                }
            },
            addFolderPrompt: {
                FenixuzPromptAlert.run(window: window,
                                       title: FenixuzL10n.current.tasks_newFolder,
                                       placeholder: FenixuzL10n.current.tasks_folderNamePlaceholder) { name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        FenixuzTasksDatabase.shared.addFolder(title: trimmed)
                        reload()
                    }
                }
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<TasksEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = tasksEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareTasksTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
            }
            |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))

        reload()
    }

    deinit {
        disposable.dispose()
    }
}

// MARK: - Task list (inside one folder)

private enum TaskListEntryId: Hashable {
    case section(Int)
    case task(String)
    case addTask
    case footer
}

private enum TaskListEntry: Comparable, Identifiable {
    case section(Int)
    case task(Int, FenixuzTodoTask, GeneralViewType)
    case addTask(Int, GeneralViewType)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return TaskListEntryId.section(id)
        case let .task(_, t, _): return TaskListEntryId.task(t.id)
        case .addTask: return TaskListEntryId.addTask
        case .footer: return TaskListEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id): return id * 1000
        case let .task(i, _, _): return i
        case let .addTask(i, _): return i
        case let .footer(i, _): return i
        }
    }

    static func < (lhs: TaskListEntry, rhs: TaskListEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: TaskListEntry, rhs: TaskListEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.task(l1, l2, l3), .task(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case let (.addTask(l1, l2), .addTask(r1, r2)): return l1 == r1 && l2 == r2
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: TaskListArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 16, stableId: stableId, viewType: .separator)
        case let .task(_, task, viewType):
            let prefix = task.isCompleted ? "✓ " : "○ "
            let subtitle: String?
            if let dueAt = task.dueAt {
                subtitle = stringForTimestampShort(dueAt)
            } else {
                subtitle = nil
            }
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: prefix + task.title,
                description: subtitle,
                type: .next,
                viewType: viewType,
                action: { arguments.editTask(task) }
            )
        case let .addTask(_, viewType):
            return GeneralInteractedRowItem(
                initialSize, stableId: stableId,
                name: FenixuzL10n.current.tasks_addTask,
                type: .none,
                viewType: viewType,
                action: { arguments.addTaskPrompt() }
            )
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

private func stringForTimestampShort(_ ts: Int32) -> String {
    let d = Date(timeIntervalSince1970: TimeInterval(ts))
    let f = DateFormatter()
    f.dateStyle = .short
    f.timeStyle = .short
    return f.string(from: d)
}

private struct TaskListState: Equatable {
    var tasks: [FenixuzTodoTask]
}

private final class TaskListArguments {
    let editTask: (FenixuzTodoTask) -> Void
    let addTaskPrompt: () -> Void
    init(editTask: @escaping (FenixuzTodoTask) -> Void,
         addTaskPrompt: @escaping () -> Void) {
        self.editTask = editTask
        self.addTaskPrompt = addTaskPrompt
    }
}

private func taskListEntries(state: TaskListState, l10n: FenixuzL10n) -> [TaskListEntry] {
    var entries: [TaskListEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))

    let tasks = state.tasks
    if tasks.isEmpty {
        entries.append(.addTask(next(), .singleItem))
    } else {
        for (i, task) in tasks.enumerated() {
            let viewType: GeneralViewType
            if i == 0 { viewType = .firstItem }
            else { viewType = .innerItem }
            entries.append(.task(next(), task, viewType))
        }
        entries.append(.addTask(next(), .lastItem))
    }

    entries.append(.section(99))
    entries.append(.footer(next(), l10n.tasks_listFooter))

    return entries
}

private func prepareTaskListTransition(left: [AppearanceWrapperEntry<TaskListEntry>], right: [AppearanceWrapperEntry<TaskListEntry>], arguments: TaskListArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

final class FenixuzTaskListController: TableViewController {

    private let folder: FenixuzTodoFolder
    private let onChange: () -> Void
    private let disposable = MetaDisposable()
    private let statePromise = ValuePromise(TaskListState(tasks: []), ignoreRepeated: true)
    private let stateValue = Atomic(value: TaskListState(tasks: []))

    override var defaultBarTitle: String {
        return folder.title
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    init(context: AccountContext, folder: FenixuzTodoFolder, onChange: @escaping () -> Void) {
        self.folder = folder
        self.onChange = onChange
        super.init(context)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        let window = context.window
        let folderId = folder.id

        let reload: () -> Void = { [weak self] in
            guard let self = self else { return }
            let tasks = FenixuzTasksDatabase.shared.loadTasks(folderId: folderId)
            let next = self.stateValue.modify { _ in TaskListState(tasks: tasks) }
            self.statePromise.set(next)
        }

        let arguments = TaskListArguments(
            editTask: { [weak self] task in
                guard let self = self else { return }
                self.navigationController?.push(FenixuzTaskDetailController(context: self.context, task: task, onChange: {
                    reload()
                    self.onChange()
                }))
            },
            addTaskPrompt: { [weak self] in
                guard let self = self else { return }
                FenixuzPromptAlert.run(window: window,
                                       title: FenixuzL10n.current.tasks_newTask,
                                       placeholder: FenixuzL10n.current.tasks_taskTitlePlaceholder) { name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        _ = FenixuzTasksDatabase.shared.addTask(folderId: folderId, title: trimmed)
                        reload()
                        self.onChange()
                    }
                }
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<TaskListEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = taskListEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareTaskListTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
            }
            |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))

        reload()
    }

    deinit {
        disposable.dispose()
    }
}

// MARK: - Task detail

private enum TaskDetailEntryId: Hashable {
    case section(Int)
    case title
    case description
    case toggleDone
    case deleteAction
    case footer
}

private enum TaskDetailEntry: Comparable, Identifiable {
    case section(Int)
    case title(Int, String /* placeholder */, String /* value */)
    case description(Int, String /* placeholder */, String /* value */)
    case toggleDone(Int, String, Bool, GeneralViewType)
    case deleteAction(Int, String, GeneralViewType)
    case footer(Int, String)

    var stableId: AnyHashable {
        switch self {
        case let .section(id): return TaskDetailEntryId.section(id)
        case .title: return TaskDetailEntryId.title
        case .description: return TaskDetailEntryId.description
        case .toggleDone: return TaskDetailEntryId.toggleDone
        case .deleteAction: return TaskDetailEntryId.deleteAction
        case .footer: return TaskDetailEntryId.footer
        }
    }

    var sortIndex: Int {
        switch self {
        case let .section(id): return id * 1000
        case let .title(i, _, _): return i
        case let .description(i, _, _): return i
        case let .toggleDone(i, _, _, _): return i
        case let .deleteAction(i, _, _): return i
        case let .footer(i, _): return i
        }
    }

    static func < (lhs: TaskDetailEntry, rhs: TaskDetailEntry) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }

    static func == (lhs: TaskDetailEntry, rhs: TaskDetailEntry) -> Bool {
        switch (lhs, rhs) {
        case let (.section(l), .section(r)): return l == r
        case let (.title(l1, l2, l3), .title(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case let (.description(l1, l2, l3), .description(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case let (.toggleDone(l1, l2, l3, l4), .toggleDone(r1, r2, r3, r4)):
            return l1 == r1 && l2 == r2 && l3 == r3 && l4 == r4
        case let (.deleteAction(l1, l2, l3), .deleteAction(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case let (.footer(l1, l2), .footer(r1, r2)): return l1 == r1 && l2 == r2
        default: return false
        }
    }

    func item(_ arguments: TaskDetailArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 16, stableId: stableId, viewType: .separator)
        case let .title(_, placeholder, value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: placeholder, text: value, limit: 200,
                                       textChangeHandler: { arguments.updateTitle($0) }, holdText: true,
                                       automaticallyBecomeResponder: false)
        case let .description(_, placeholder, value):
            return GeneralInputRowItem(initialSize, stableId: stableId, placeholder: placeholder, text: value, limit: 1000,
                                       textChangeHandler: { arguments.updateDescription($0) }, holdText: true,
                                       automaticallyBecomeResponder: false)
        case let .toggleDone(_, title, value, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title,
                                            type: .switchable(value), viewType: viewType,
                                            action: { arguments.toggleDone() })
        case let .deleteAction(_, title, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title,
                                            type: .none, viewType: viewType,
                                            action: { arguments.delete() })
        case let .footer(_, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, viewType: .textBottomItem)
        }
    }
}

private struct TaskDetailState: Equatable {
    var title: String
    var description: String
    var isCompleted: Bool
}

private final class TaskDetailArguments {
    let updateTitle: (String) -> Void
    let updateDescription: (String) -> Void
    let toggleDone: () -> Void
    let delete: () -> Void
    init(updateTitle: @escaping (String) -> Void,
         updateDescription: @escaping (String) -> Void,
         toggleDone: @escaping () -> Void,
         delete: @escaping () -> Void) {
        self.updateTitle = updateTitle
        self.updateDescription = updateDescription
        self.toggleDone = toggleDone
        self.delete = delete
    }
}

private func taskDetailEntries(state: TaskDetailState, l10n: FenixuzL10n) -> [TaskDetailEntry] {
    var entries: [TaskDetailEntry] = []
    var idx = 0
    let next: () -> Int = { idx += 1; return idx }

    entries.append(.section(1))
    entries.append(.title(next(), l10n.tasks_taskTitlePlaceholder, state.title))
    entries.append(.section(2))
    entries.append(.description(next(), l10n.tasks_taskDescPlaceholder, state.description))
    entries.append(.section(3))
    entries.append(.toggleDone(next(), l10n.tasks_markCompleted, state.isCompleted, .singleItem))
    entries.append(.section(4))
    entries.append(.deleteAction(next(), l10n.tasks_deleteTask, .singleItem))
    entries.append(.section(99))
    entries.append(.footer(next(), l10n.tasks_detailFooter))

    return entries
}

private func prepareTaskDetailTransition(left: [AppearanceWrapperEntry<TaskDetailEntry>], right: [AppearanceWrapperEntry<TaskDetailEntry>], arguments: TaskDetailArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

final class FenixuzTaskDetailController: TableViewController {

    private let task: FenixuzTodoTask
    private let onChange: () -> Void
    private let disposable = MetaDisposable()
    private let statePromise: ValuePromise<TaskDetailState>
    private let stateValue: Atomic<TaskDetailState>

    override var defaultBarTitle: String {
        return FenixuzL10n.current.tasks_taskDetailTitle
    }

    override var removeAfterDisapper: Bool {
        return false
    }

    init(context: AccountContext, task: FenixuzTodoTask, onChange: @escaping () -> Void) {
        self.task = task
        self.onChange = onChange
        let initial = TaskDetailState(title: task.title, description: task.description ?? "", isCompleted: task.isCompleted)
        self.statePromise = ValuePromise(initial, ignoreRepeated: true)
        self.stateValue = Atomic(value: initial)
        super.init(context)
    }

    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func persist() {
        let s = stateValue.with { $0 }
        FenixuzTasksDatabase.shared.updateTask(id: task.id, title: s.title, description: s.description.isEmpty ? nil : s.description, dueAt: task.dueAt, priority: task.priority)
        if s.isCompleted != task.isCompleted {
            FenixuzTasksDatabase.shared.toggleTask(id: task.id)
        }
        onChange()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let taskId = task.id

        let updateState: ((inout TaskDetailState) -> Void) -> Void = { [weak self] mutate in
            guard let self = self else { return }
            let new = self.stateValue.modify { current in
                var s = current
                mutate(&s)
                return s
            }
            self.statePromise.set(new)
        }

        let arguments = TaskDetailArguments(
            updateTitle: { [weak self] text in
                updateState { s in s.title = text }
                self?.persist()
            },
            updateDescription: { [weak self] text in
                updateState { s in s.description = text }
                self?.persist()
            },
            toggleDone: { [weak self] in
                updateState { s in s.isCompleted.toggle() }
                self?.persist()
            },
            delete: { [weak self] in
                FenixuzTasksDatabase.shared.removeTask(id: taskId)
                self?.onChange()
                self?.navigationController?.back()
            }
        )

        let initialSize = self.atomicSize
        let previousEntries = Atomic<[AppearanceWrapperEntry<TaskDetailEntry>]>(value: [])

        let signal = combineLatest(queue: prepareQueue, statePromise.get(), appearanceSignal)
            |> map { state, appearance -> TableUpdateTransition in
                let l10n = FenixuzL10n(languageCode: appCurrentLanguage.languageCode)
                let entries = taskDetailEntries(state: state, l10n: l10n)
                    .map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
                let previous = previousEntries.swap(entries)
                return prepareTaskDetailTransition(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify { $0 })
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

// MARK: - Simple text-prompt helper

enum FenixuzPromptAlert {
    /// NSAlert sheet with a single text field — used for "Add folder…" /
    /// "Add task…" prompts.
    static func run(window: Window, title: String, placeholder: String, completion: @escaping (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.alertStyle = .informational
        alert.addButton(withTitle: FenixuzL10n.current.alert_create)
        alert.addButton(withTitle: FenixuzL10n.current.alert_cancel)

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = placeholder
        alert.accessoryView = input
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                completion(input.stringValue)
            }
        }
    }
}
