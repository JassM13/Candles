import Foundation
import Combine

class AccountManager: ObservableObject {
    static let shared = AccountManager() // Singleton instance
    @Published var accounts: [Account] = []
    private var cancellables = Set<AnyCancellable>()

    private init() { // Private initializer for singleton
        loadAccountsFromDatabase()
    }

    private func loadAccountsFromDatabase() {
        do {
            self.accounts = try DatabaseService.shared.fetchAllAccounts()
            print("Accounts loaded from database.")
        } catch {
            print("Error loading accounts from database: \(error). Starting with an empty list.")
            self.accounts = []
        }
    }

    func addAccount(broker: Broker, userName: String, token: String, displayName: String? = nil) {
        let newAccount = Account(broker: broker, userName: userName, token: token, displayName: displayName)
        // Prevent adding duplicate accounts (simple check based on broker and username)
        // Prevent adding duplicate accounts (simple check based on broker and username)
        if !accounts.contains(where: { $0.broker == newAccount.broker && $0.userName == newAccount.userName }) {
            do {
                try DatabaseService.shared.saveAccount(newAccount)
                accounts.append(newAccount)
                print("Account added and saved: \(newAccount.displayName ?? "Unknown Account")")
            } catch {
                print("Error saving account \(newAccount.displayName ?? "Unknown Account") to database: \(error)")
            }
        } else {
            print("Account for \(broker.rawValue) - \(userName) already exists.")
        }
    }

    func removeAccount(at offsets: IndexSet) {
        let accountsToRemove = offsets.map { accounts[$0] }
        accounts.remove(atOffsets: offsets)
        for account in accountsToRemove {
            do {
                try DatabaseService.shared.deleteAccount(account: account)
                print("Account removed from database: \(account.displayName ?? "Unknown Account")")
            } catch {
                print("Error removing account \(account.displayName ?? "Unknown Account") from database: \(error)")
            }
        }
    }
    
    func removeAccount(id: UUID) {
        if let accountToRemove = accounts.first(where: { $0.id == id }) {
            accounts.removeAll { $0.id == id }
            do {
                try DatabaseService.shared.deleteAccount(id: id)
                print("Account with ID \(id) removed from database.")
            } catch {
                print("Error removing account with ID \(id) from database: \(error)")
            }
        } else {
            print("Account with ID \(id) not found.")
        }
    }

}