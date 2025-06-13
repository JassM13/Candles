import Foundation

struct Account: Identifiable, Codable {
    let id: UUID
    let broker: Broker
    let userName: String
    let token: String // Store the session token
    var displayName: String? // Optional display name for the account

    init(id: UUID = UUID(), broker: Broker, userName: String, token: String, displayName: String? = nil) {
        self.id = id
        self.broker = broker
        self.userName = userName
        self.token = token
        self.displayName = displayName ?? "\(broker.rawValue.capitalized) - \(userName)"
    }
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