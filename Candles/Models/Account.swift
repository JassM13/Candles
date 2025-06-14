import Foundation
import GRDB

struct Account: Identifiable, Codable, FetchableRecord, PersistableRecord {
    let id: UUID
    let broker: Broker
    let userName: String
    let token: String // Store the session token
    var displayName: String? // Optional display name for the account
    var subAccounts: [SubAccount]? // Optional array for sub-accounts

    init(id: UUID = UUID(), broker: Broker, userName: String, token: String, displayName: String? = nil, subAccounts: [SubAccount]? = nil) {
        self.id = id
        self.broker = broker
        self.userName = userName
        self.token = token
        self.displayName = displayName ?? "\(broker.rawValue.capitalized) - \(userName)"
        self.subAccounts = subAccounts
    }

    // GRDB Column mapping
    enum Columns: String, ColumnExpression {
        case id, broker, userName, token, displayName // subAccounts will not be stored directly in this table's column
    }

    // subAccounts are now of type [SubAccount] and SubAccount is Codable.
    // If the API returns subAccounts nested within the main account JSON, Swift's automatic Codable synthesis should handle it.
    // If subAccounts are fetched via a separate API call, they would be assigned to this property manually after fetching.
    // For GRDB, subAccounts would typically be handled as a separate table and relation if stored in the local DB.
    // The current structure assumes subAccounts might come from an API response and are not persisted directly in the Account table.

}

// Conformance to Broker for Codable if Broker is not already Codable
// Assuming Broker enum is in AuthenticationRoutes.swift and might need to be made Codable if not already.
// If Broker is already Codable, this extension might not be strictly necessary here,
// but it's good to ensure all parts of Account are Codable.

// Example: Making Broker Codable (if it's not already in its own file)
/*
extension Broker: Codable {
    // Codable conformance will be synthesized if all cases have raw values of a Codable type (like String)
}
*/