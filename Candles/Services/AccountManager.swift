import Foundation
import Combine

class AccountManager: ObservableObject {
    static let shared = AccountManager() // Singleton instance
    @Published var accounts: [Account] = []

    // TODO: Implement persistent storage using UserDefaults, Keychain, or Core Data.
    // For now, accounts are stored in-memory and will be lost when the app closes.

    private init() { // Private initializer for singleton
        // Load accounts from persistent storage if implemented
        // self.accounts = loadAccountsFromStorage()
    }

    func addAccount(broker: Broker, userName: String, token: String, displayName: String? = nil) {
        let newAccount = Account(broker: broker, userName: userName, token: token, displayName: displayName)
        // Prevent adding duplicate accounts (simple check based on broker and username)
        if !accounts.contains(where: { $0.broker == newAccount.broker && $0.userName == newAccount.userName }) {
            accounts.append(newAccount)
            // saveAccountsToStorage() // Save after modification if persistent storage is used
            print("Account added: \(newAccount.displayName ?? "Unknown Account")")
        } else {
            print("Account for \(broker.rawValue) - \(userName) already exists.")
        }
    }

    func removeAccount(at offsets: IndexSet) {
        accounts.remove(atOffsets: offsets)
        // saveAccountsToStorage()
    }
    
    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        // saveAccountsToStorage()
    }

    // Example functions for saving/loading (to be implemented with actual storage)
    /*
    private func saveAccountsToStorage() {
        // Implement saving logic (e.g., to UserDefaults or Keychain)
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "userAccounts")
        }
    }

    private func loadAccountsFromStorage() -> [Account] {
        // Implement loading logic
        if let savedAccounts = UserDefaults.standard.data(forKey: "userAccounts") {
            if let decodedAccounts = try? JSONDecoder().decode([Account].self, from: savedAccounts) {
                return decodedAccounts
            }
        }
        return []
    }
    */
}