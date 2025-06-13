import Foundation

struct Contract: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let tickSize: Double
    let tickValue: Double
    let activeContract: Bool
}

struct SearchResponse: Codable {
    let contracts: [Contract]
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
}