import Foundation

struct SubAccount: Identifiable, Codable {
    let id: Int
    let name: String
    let balance: Double
    let canTrade: Bool
    let isVisible: Bool
}