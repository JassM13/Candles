import Foundation
import GRDB

class WatchlistDatabaseService {
    static let shared = WatchlistDatabaseService()
    private var dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let dbPath =
                try fileManager
                .url(
                    for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil,
                    create: true
                )
                .appendingPathComponent("watchlist.sqlite") // Changed database file name
                .path

            dbQueue = try DatabaseQueue(path: dbPath)
            try setupDatabase()
        } catch {
            // Handle errors appropriately in a real app (e.g., fatalError, logging, UI alert)
            fatalError("Failed to initialize database: \(error)")
        }
    }

    private func setupDatabase() throws {
        try dbQueue.write { db in
            if try !db.tableExists(WatchlistItem.databaseTableName) {
                try db.create(table: WatchlistItem.databaseTableName) { t in
                    t.column(WatchlistItem.Columns.id.rawValue, .text).primaryKey()
                    t.column(WatchlistItem.Columns.name.rawValue, .text).notNull()
                    t.column(WatchlistItem.Columns.description.rawValue, .text).notNull()
                    t.column(WatchlistItem.Columns.tickSize.rawValue, .double).notNull()
                    t.column(WatchlistItem.Columns.tickValue.rawValue, .double).notNull()
                    t.column(WatchlistItem.Columns.activeContract.rawValue, .boolean).notNull()
                }
            }
        }
    }

    // MARK: - Watchlist Item Operations

    func saveWatchlistItem(_ item: WatchlistItem) throws {
        try dbQueue.write { db in
            try item.save(db)
        }
    }

    func fetchAllWatchlistItems() throws -> [WatchlistItem] {
        try dbQueue.read { db in
            try WatchlistItem.fetchAll(db)
        }
    }

    func deleteWatchlistItem(id: String) throws {
        try dbQueue.write { db in
            _ = try WatchlistItem.deleteOne(db, key: id)
        }
    }

    func deleteWatchlistItem(item: WatchlistItem) throws {
        try dbQueue.write { db in
            _ = try item.delete(db)
        }
    }

    func deleteAllWatchlistItems() throws {
        try dbQueue.write { db in
            _ = try WatchlistItem.deleteAll(db)
        }
    }
}
