import Foundation
import GRDB

struct WatchlistItem: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: String // Contract ID, e.g., "CON.F.US.ENQ.H25"
    var name: String // e.g., "ENQH25"
    var description: String // e.g., "E-mini NASDAQ-100: March 2025"
    var tickSize: Double
    var tickValue: Double
    var activeContract: Bool

    // Conform to GRDB's PersistableRecord
    static var databaseTableName = "watchlistItem"

    // Define database columns
    enum Columns: String, ColumnExpression {
        case id, name, description, tickSize, tickValue, activeContract
    }

    // Initializer from a search result contract (or similar structure)
    init(id: String, name: String, description: String, tickSize: Double, tickValue: Double, activeContract: Bool) {
        self.id = id
        self.name = name
        self.description = description
        self.tickSize = tickSize
        self.tickValue = tickValue
        self.activeContract = activeContract
    }
    
    // Decoder for GRDB
    init(row: Row) {
        id = row[Columns.id]
        name = row[Columns.name]
        description = row[Columns.description]
        tickSize = row[Columns.tickSize]
        tickValue = row[Columns.tickValue]
        activeContract = row[Columns.activeContract]
    }

    // Encoder for GRDB
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id
        container[Columns.name] = name
        container[Columns.description] = description
        container[Columns.tickSize] = tickSize
        container[Columns.tickValue] = tickValue
        container[Columns.activeContract] = activeContract
    }
}