import GRDB
import Foundation

class DatabaseService {
    static let shared = DatabaseService()
    private var dbQueue: DatabaseQueue

    private init() {
        do {
            let fileManager = FileManager.default
            let dbPath = try fileManager
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("accounts.sqlite")
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
            if try !db.tableExists("account") {
                try db.create(table: "account") { t in
                    t.column("id", .text).primaryKey()
                    t.column("broker", .text).notNull() // Assuming Broker.rawValue is String
                    t.column("userName", .text).notNull()
                    t.column("token", .text).notNull()
                    t.column("displayName", .text)
                }
            }
        }
    }

    // MARK: - Account Operations

    func saveAccount(_ account: Account) throws {
        try dbQueue.write { db in
            try account.save(db)
        }
    }

    func fetchAllAccounts() throws -> [Account] {
        try dbQueue.read { db in
            try Account.fetchAll(db)
        }
    }

    func deleteAccount(id: UUID) throws {
        try dbQueue.write { db in
            _ = try Account.deleteOne(db, key: id.uuidString)
        }
    }
    
    func deleteAccount(account: Account) throws {
        try dbQueue.write { db in
            _ = try account.delete(db)
        }
    }

    func deleteAllAccounts() throws {
        try dbQueue.write { db in
            _ = try Account.deleteAll(db)
        }
    }
}