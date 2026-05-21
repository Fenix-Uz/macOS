//
//  FenixuzTasksDatabase.swift
//  Telegram-Mac
//
//  iOS portasi: submodules/Fenixuz/Tasks/Sources/TodoDatabase.swift
//                + submodules/Fenixuz/Tasks/Sources/TodoStorage.swift
//
//  Local SQLite-backed Todo store. Stores at
//    ~/Library/Application Support/uz.fenixuz.app/fenixuz_todo.sqlite
//
//  Schema (user_version = 1):
//    folders: id TEXT PRIMARY KEY, title TEXT, sort_order INTEGER, created_at INTEGER
//    tasks:   id TEXT PRIMARY KEY, folder_id TEXT FK, title TEXT, description TEXT,
//             due_at INTEGER, priority INTEGER, is_completed INTEGER, completed_at INTEGER,
//             sort_order INTEGER, created_at INTEGER, updated_at INTEGER
//
//  Mac difference: iOS uses ~/Documents which is the iOS-specific sandbox docs
//  dir. macOS uses ~/Library/Application Support/<bundle id>/ which is the
//  conventional Mac location. Schema and SQL are byte-for-byte identical.

import Foundation
import sqlcipher

private let SQLITE_TRANSIENT_DESTRUCTOR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Data models

public struct FenixuzTodoFolder: Equatable {
    public let id: String
    public var title: String
    public var sortOrder: Int
    public let createdDate: Int32

    public init(id: String, title: String, sortOrder: Int, createdDate: Int32) {
        self.id = id
        self.title = title
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }
}

public struct FenixuzTodoTask: Equatable {
    public let id: String
    public let folderId: String
    public var title: String
    public var description: String?
    public var dueAt: Int32?
    public var priority: Int        // 0=none, 1=low, 2=normal, 3=high, 4=urgent
    public var isCompleted: Bool
    public var completedAt: Int32?
    public var sortOrder: Int
    public let createdDate: Int32
    public var updatedAt: Int32

    public init(id: String, folderId: String, title: String,
                description: String?, dueAt: Int32?, priority: Int,
                isCompleted: Bool, completedAt: Int32?,
                sortOrder: Int, createdDate: Int32, updatedAt: Int32) {
        self.id = id
        self.folderId = folderId
        self.title = title
        self.description = description
        self.dueAt = dueAt
        self.priority = priority
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }
}

// MARK: - Database

public final class FenixuzTasksDatabase {
    public static let shared = FenixuzTasksDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "uz.fenixuz.tasks.db")
    private let dbPath: String

    private init() {
        // ~/Library/Application Support/<bundle>/fenixuz_todo.sqlite
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleId = Bundle.main.bundleIdentifier ?? "uz.fenixuz.app"
        let dir = appSupport.appendingPathComponent(bundleId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.dbPath = dir.appendingPathComponent("fenixuz_todo.sqlite").path
        self.openAndConfigure()
        self.migrate()
    }

    private func openAndConfigure() {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let res = sqlite3_open_v2(self.dbPath, &self.db, flags, nil)
        if res != SQLITE_OK {
            print("[FenixuzTasks] sqlite3_open_v2 failed: \(res) path=\(self.dbPath)")
            return
        }
        exec("PRAGMA journal_mode = WAL;")
        exec("PRAGMA synchronous = NORMAL;")
        exec("PRAGMA foreign_keys = ON;")
        exec("PRAGMA busy_timeout = 3000;")
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        let res = sqlite3_exec(self.db, sql, nil, nil, &err)
        if res != SQLITE_OK, let err = err {
            print("[FenixuzTasks] exec error: \(String(cString: err)) for SQL: \(sql)")
            sqlite3_free(err)
        }
    }

    private func userVersion() -> Int32 {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(self.db, "PRAGMA user_version;", -1, &stmt, nil) != SQLITE_OK { return 0 }
        if sqlite3_step(stmt) != SQLITE_ROW { return 0 }
        return sqlite3_column_int(stmt, 0)
    }

    private func setUserVersion(_ v: Int32) { exec("PRAGMA user_version = \(v);") }

    private func migrate() {
        let v = self.userVersion()
        if v < 1 {
            exec("""
            CREATE TABLE IF NOT EXISTS folders (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL
            );
            """)
            exec("""
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                folder_id TEXT REFERENCES folders(id) ON DELETE CASCADE,
                title TEXT NOT NULL,
                description TEXT,
                due_at INTEGER,
                priority INTEGER NOT NULL DEFAULT 0,
                is_completed INTEGER NOT NULL DEFAULT 0,
                completed_at INTEGER,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
            """)
            exec("CREATE INDEX IF NOT EXISTS idx_tasks_folder_sort ON tasks(folder_id, sort_order);")
            exec("CREATE INDEX IF NOT EXISTS idx_tasks_completed_due ON tasks(is_completed, due_at);")
            exec("CREATE INDEX IF NOT EXISTS idx_tasks_due_pending ON tasks(due_at) WHERE is_completed = 0;")
            setUserVersion(1)
        }
    }

    // MARK: - Folders

    public func loadFolders() -> [FenixuzTodoFolder] {
        return queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT id, title, sort_order, created_at FROM folders ORDER BY sort_order, created_at;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            var out: [FenixuzTodoFolder] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(FenixuzTodoFolder(
                    id: String(cString: sqlite3_column_text(stmt, 0)),
                    title: String(cString: sqlite3_column_text(stmt, 1)),
                    sortOrder: Int(sqlite3_column_int(stmt, 2)),
                    createdDate: sqlite3_column_int(stmt, 3)
                ))
            }
            return out
        }
    }

    public func addFolder(title: String) {
        queue.sync {
            let count = countFolders()
            insertFolder(id: UUID().uuidString, title: title, sortOrder: count, createdAt: Int32(Date().timeIntervalSince1970))
        }
    }

    private func countFolders() -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(self.db, "SELECT COUNT(*) FROM folders;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func insertFolder(id: String, title: String, sortOrder: Int, createdAt: Int32) {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "INSERT OR REPLACE INTO folders (id, title, sort_order, created_at) VALUES (?, ?, ?, ?);"
        guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_int(stmt, 3, Int32(sortOrder))
        sqlite3_bind_int(stmt, 4, createdAt)
        _ = sqlite3_step(stmt)
    }

    public func updateFolderTitle(id: String, title: String) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "UPDATE folders SET title = ? WHERE id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            _ = sqlite3_step(stmt)
        }
    }

    public func removeFolder(id: String) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, "DELETE FROM folders WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            _ = sqlite3_step(stmt)
        }
    }

    // MARK: - Tasks

    public func loadTasks(folderId: String? = nil) -> [FenixuzTodoTask] {
        return queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql: String
            if folderId != nil {
                sql = "SELECT id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at FROM tasks WHERE folder_id = ? ORDER BY is_completed ASC, sort_order ASC, created_at ASC;"
            } else {
                sql = "SELECT id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at FROM tasks ORDER BY is_completed ASC, sort_order ASC, created_at ASC;"
            }
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            if let folderId = folderId {
                sqlite3_bind_text(stmt, 1, folderId, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            }
            var out: [FenixuzTodoTask] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(taskFromRow(stmt))
            }
            return out
        }
    }

    public func loadTasksDueToday() -> [FenixuzTodoTask] {
        return queue.sync {
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.timeIntervalSince1970
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = """
            SELECT id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at
            FROM tasks
            WHERE is_completed = 0 AND due_at IS NOT NULL AND due_at < ?
            ORDER BY due_at ASC;
            """
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int64(stmt, 1, Int64(endOfDay))
            var out: [FenixuzTodoTask] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(taskFromRow(stmt))
            }
            return out
        }
    }

    public func loadTasksUpcoming() -> [FenixuzTodoTask] {
        return queue.sync {
            let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!.timeIntervalSince1970
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = """
            SELECT id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at
            FROM tasks
            WHERE is_completed = 0 AND due_at IS NOT NULL AND due_at >= ?
            ORDER BY due_at ASC;
            """
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_int64(stmt, 1, Int64(startOfNextDay))
            var out: [FenixuzTodoTask] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(taskFromRow(stmt))
            }
            return out
        }
    }

    private func taskFromRow(_ stmt: OpaquePointer?) -> FenixuzTodoTask {
        let description: String? = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, 3))
        let dueAt: Int32? = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_int(stmt, 4)
        let completedAt: Int32? = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : sqlite3_column_int(stmt, 7)
        return FenixuzTodoTask(
            id: String(cString: sqlite3_column_text(stmt, 0)),
            folderId: String(cString: sqlite3_column_text(stmt, 1)),
            title: String(cString: sqlite3_column_text(stmt, 2)),
            description: description,
            dueAt: dueAt,
            priority: Int(sqlite3_column_int(stmt, 5)),
            isCompleted: sqlite3_column_int(stmt, 6) != 0,
            completedAt: completedAt,
            sortOrder: Int(sqlite3_column_int(stmt, 8)),
            createdDate: sqlite3_column_int(stmt, 9),
            updatedAt: sqlite3_column_int(stmt, 10)
        )
    }

    @discardableResult
    public func addTask(folderId: String, title: String, description: String? = nil, dueAt: Int32? = nil, priority: Int = 0) -> FenixuzTodoTask {
        return queue.sync {
            let now = Int32(Date().timeIntervalSince1970)
            let id = UUID().uuidString
            let count = countTasksInFolder(folderId: folderId)
            insertTask(id: id, folderId: folderId, title: title, description: description, dueAt: dueAt, priority: priority,
                       isCompleted: false, completedAt: nil, sortOrder: count, createdAt: now, updatedAt: now)
            return FenixuzTodoTask(id: id, folderId: folderId, title: title, description: description, dueAt: dueAt, priority: priority,
                                   isCompleted: false, completedAt: nil, sortOrder: count, createdDate: now, updatedAt: now)
        }
    }

    private func countTasksInFolder(folderId: String) -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT COUNT(*) FROM tasks WHERE folder_id = ?;"
        guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        sqlite3_bind_text(stmt, 1, folderId, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func insertTask(id: String, folderId: String, title: String, description: String?, dueAt: Int32?, priority: Int,
                            isCompleted: Bool, completedAt: Int32?, sortOrder: Int, createdAt: Int32, updatedAt: Int32) {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = """
        INSERT OR REPLACE INTO tasks
        (id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_text(stmt, 2, folderId, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        sqlite3_bind_text(stmt, 3, title, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        if let description = description {
            sqlite3_bind_text(stmt, 4, description, -1, SQLITE_TRANSIENT_DESTRUCTOR)
        } else {
            sqlite3_bind_null(stmt, 4)
        }
        if let dueAt = dueAt {
            sqlite3_bind_int(stmt, 5, dueAt)
        } else {
            sqlite3_bind_null(stmt, 5)
        }
        sqlite3_bind_int(stmt, 6, Int32(priority))
        sqlite3_bind_int(stmt, 7, isCompleted ? 1 : 0)
        if let completedAt = completedAt {
            sqlite3_bind_int(stmt, 8, completedAt)
        } else {
            sqlite3_bind_null(stmt, 8)
        }
        sqlite3_bind_int(stmt, 9, Int32(sortOrder))
        sqlite3_bind_int(stmt, 10, createdAt)
        sqlite3_bind_int(stmt, 11, updatedAt)
        _ = sqlite3_step(stmt)
    }

    public func updateTask(id: String, title: String, description: String?, dueAt: Int32?, priority: Int) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "UPDATE tasks SET title = ?, description = ?, due_at = ?, priority = ?, updated_at = ? WHERE id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            if let description = description {
                sqlite3_bind_text(stmt, 2, description, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            if let dueAt = dueAt {
                sqlite3_bind_int(stmt, 3, dueAt)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_int(stmt, 4, Int32(priority))
            sqlite3_bind_int(stmt, 5, Int32(Date().timeIntervalSince1970))
            sqlite3_bind_text(stmt, 6, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            _ = sqlite3_step(stmt)
        }
    }

    public func toggleTask(id: String) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let now = Int32(Date().timeIntervalSince1970)
            let sql = """
            UPDATE tasks
            SET is_completed = CASE WHEN is_completed = 0 THEN 1 ELSE 0 END,
                completed_at = CASE WHEN is_completed = 0 THEN ? ELSE NULL END,
                updated_at = ?
            WHERE id = ?;
            """
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int(stmt, 1, now)
            sqlite3_bind_int(stmt, 2, now)
            sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            _ = sqlite3_step(stmt)
        }
    }

    public func removeTask(id: String) {
        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(self.db, "DELETE FROM tasks WHERE id = ?;", -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            _ = sqlite3_step(stmt)
        }
    }

    public func reorderTasks(folderId: String, idsInOrder: [String]) {
        queue.sync {
            exec("BEGIN TRANSACTION;")
            for (i, id) in idsInOrder.enumerated() {
                var stmt: OpaquePointer?
                let sql = "UPDATE tasks SET sort_order = ? WHERE id = ?;"
                if sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK {
                    sqlite3_bind_int(stmt, 1, Int32(i))
                    sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT_DESTRUCTOR)
                    _ = sqlite3_step(stmt)
                }
                sqlite3_finalize(stmt)
            }
            exec("COMMIT;")
        }
    }

    public func searchTasks(query: String) -> [FenixuzTodoTask] {
        return queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = """
            SELECT id, folder_id, title, description, due_at, priority, is_completed, completed_at, sort_order, created_at, updated_at
            FROM tasks
            WHERE title LIKE ? OR description LIKE ?
            ORDER BY is_completed ASC, due_at IS NULL ASC, due_at ASC, created_at DESC
            LIMIT 200;
            """
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            let like = "%\(query)%"
            sqlite3_bind_text(stmt, 1, like, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            sqlite3_bind_text(stmt, 2, like, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            var out: [FenixuzTodoTask] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                out.append(taskFromRow(stmt))
            }
            return out
        }
    }

    public func countActiveAndTotal(folderId: String) -> (done: Int, total: Int) {
        return queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT SUM(is_completed) AS done, COUNT(*) AS total FROM tasks WHERE folder_id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return (0, 0) }
            sqlite3_bind_text(stmt, 1, folderId, -1, SQLITE_TRANSIENT_DESTRUCTOR)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return (0, 0) }
            let done = sqlite3_column_type(stmt, 0) == SQLITE_NULL ? 0 : Int(sqlite3_column_int(stmt, 0))
            let total = Int(sqlite3_column_int(stmt, 1))
            return (done, total)
        }
    }
}
